# -*- coding: utf-8 -*-
"""
스타디움 스타일 필러 배경 (Stage 30 - Colosseum Arena)
돔 형태 스타디움: 노란 좌석이 경기장을 둘러싼 관중석, 응원하는 관중 NPC
"""

import math
import random
import pygame


class Spectator:
    """관중 NPC (스타디움 관중 스타일)"""

    # 다양한 피부색
    SKIN_TONES = [
        (255, 224, 189),  # 밝은 피부
        (255, 205, 148),  # 중간 밝은 피부
        (234, 192, 134),  # 올리브
        (198, 134, 66),   # 중간 어두운 피부
        (141, 85, 36),    # 어두운 피부
        (255, 219, 172),  # 복숭아빛
    ]

    # 다양한 옷 색상 (스타디움 팀 컬러 포함)
    BODY_COLORS = [
        (200, 180, 60),   # 금색/노랑 (팀 컬러)
        (60, 80, 140),    # 파랑 (팀 컬러)
        (180, 60, 60),    # 빨강
        (60, 150, 80),    # 초록
        (150, 80, 150),   # 보라
        (180, 100, 60),   # 주황
        (255, 220, 80),   # 밝은 노랑
        (80, 100, 160),   # 남색
        (220, 200, 100),  # 연노랑
        (200, 180, 160),  # 베이지
    ]

    # 다양한 머리색
    HAIR_COLORS = [
        (30, 20, 10),     # 검정
        (60, 40, 20),     # 진갈색
        (100, 70, 40),    # 갈색
        (150, 100, 50),   # 밝은 갈색
        (200, 180, 100),  # 금발
        (80, 50, 30),     # 어두운 갈색
    ]

    def __init__(self, x: float, y: float, seed: int, size_scale: float = 1.0):
        self.x = x
        self.y = y
        self.seed = seed
        self.size_scale = size_scale

        # 랜덤 특성 (시드 기반)
        random.seed(seed)
        self.skin_color = random.choice(self.SKIN_TONES)
        self.body_color = random.choice(self.BODY_COLORS)
        self.hair_color = random.choice(self.HAIR_COLORS)

        # 얼굴형과 머리 스타일
        self.face_type = random.choice(["round", "oval", "square"])
        self.hair_style = random.choice(["short", "medium", "long", "bald"])
        self.has_hat = random.random() < 0.2  # 20% 확률로 모자

        # 애니메이션 오프셋 (개인별 차이)
        self.anim_offset = random.uniform(0, math.pi * 2)
        self.cheer_speed = random.uniform(0.8, 1.2)
        self.arm_length = random.uniform(0.8, 1.2)

        # 상태
        self.is_cheering = False
        self.cheer_intensity = random.uniform(0.5, 1.0)

        random.seed()  # 시드 리셋

    def draw(self, screen: pygame.Surface, time: float, scale: float = 1.0, is_excited: bool = False):
        """관중 그리기 (스타디움 좌석에 앉아있는 모습)"""
        s = scale * self.size_scale

        # 응원 애니메이션
        cheer_phase = time * 4 * self.cheer_speed + self.anim_offset

        if is_excited:
            bob = int(abs(math.sin(cheer_phase * 2)) * 3 * s)
            arm_raise = int(math.sin(cheer_phase) * 4 * s * self.arm_length)
        else:
            bob = int(abs(math.sin(cheer_phase * 0.5)) * 1 * s)
            arm_raise = int(math.sin(cheer_phase * 0.3) * 2 * s * self.arm_length)

        x = int(self.x)
        y = int(self.y) - bob

        # 색상 계산
        body_dark = tuple(max(0, c - 30) for c in self.body_color)
        skin_dark = tuple(max(0, c - 20) for c in self.skin_color)

        # === 몸통 (상체만 보임 - 좌석에 앉아있으므로) ===
        body_w = int(8 * s)
        body_h = int(10 * s)
        body_x = x - body_w // 2
        body_y = y

        # 몸통 그리기
        pygame.draw.rect(screen, self.body_color,
                        (body_x, body_y, body_w, body_h), border_radius=int(2 * s))
        # 음영
        pygame.draw.rect(screen, body_dark,
                        (body_x, body_y, int(2 * s), body_h), border_radius=int(1 * s))

        # === 팔 (응원 애니메이션) ===
        arm_w = int(2 * s)
        arm_h = int(6 * s)

        # 왼팔
        left_arm_y = body_y + int(2 * s) - max(0, arm_raise)
        pygame.draw.rect(screen, body_dark,
                        (body_x - arm_w + 1, left_arm_y, arm_w, arm_h - int(abs(arm_raise) * 0.3)),
                        border_radius=int(1 * s))
        # 왼손
        pygame.draw.circle(screen, self.skin_color,
                          (body_x - arm_w // 2 + 1, left_arm_y + arm_h - int(abs(arm_raise) * 0.3) - int(2 * s)),
                          int(2 * s))

        # 오른팔
        right_arm_y = body_y + int(2 * s) - max(0, -arm_raise)
        pygame.draw.rect(screen, self.body_color,
                        (body_x + body_w - 1, right_arm_y, arm_w, arm_h - int(abs(arm_raise) * 0.3)),
                        border_radius=int(1 * s))
        # 오른손
        pygame.draw.circle(screen, self.skin_color,
                          (body_x + body_w + arm_w // 2 - 1, right_arm_y + arm_h - int(abs(arm_raise) * 0.3) - int(2 * s)),
                          int(2 * s))

        # === 목 ===
        neck_w = int(3 * s)
        neck_h = int(2 * s)
        neck_x = x - neck_w // 2
        neck_y = body_y - neck_h + int(2 * s)
        pygame.draw.rect(screen, self.skin_color, (neck_x, neck_y, neck_w, neck_h + int(2 * s)))

        # === 머리 ===
        if self.face_type == "round":
            head_w, head_h = int(8 * s), int(8 * s)
        elif self.face_type == "oval":
            head_w, head_h = int(7 * s), int(9 * s)
        else:  # square
            head_w, head_h = int(8 * s), int(7 * s)

        # 머리 흔들림 (응원 중)
        head_sway = int(math.sin(cheer_phase * 1.5) * 1 * s) if is_excited else 0

        head_x = x - head_w // 2 + head_sway
        head_y = neck_y - head_h + int(3 * s)

        # 얼굴
        pygame.draw.ellipse(screen, self.skin_color, (head_x, head_y, head_w, head_h))

        # === 머리카락 ===
        if self.hair_style == "short":
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(1 * s), head_y - int(1 * s), head_w + int(2 * s), head_h // 2 + int(2 * s)))
        elif self.hair_style == "medium":
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(1 * s), head_y - int(1 * s), head_w + int(2 * s), head_h // 2 + int(3 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(1 * s), head_y + int(2 * s), int(3 * s), int(5 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x + head_w - int(2 * s), head_y + int(2 * s), int(3 * s), int(5 * s)))
        elif self.hair_style == "long":
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(1 * s), head_y - int(1 * s), head_w + int(2 * s), head_h // 2 + int(3 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(2 * s), head_y + int(2 * s), int(4 * s), int(8 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x + head_w - int(2 * s), head_y + int(2 * s), int(4 * s), int(8 * s)))

        # 모자 (팀 컬러)
        if self.has_hat:
            hat_color = random.Random(self.seed + 100).choice([(200, 180, 60), (60, 80, 140)])
            pygame.draw.ellipse(screen, hat_color,
                              (head_x - int(1 * s), head_y - int(2 * s), head_w + int(2 * s), int(5 * s)))
            pygame.draw.rect(screen, hat_color,
                            (head_x - int(3 * s), head_y + int(1 * s), head_w + int(6 * s), int(2 * s)))

        # === 눈 ===
        eye_y = head_y + head_h // 2 - int(1 * s)
        eye_spacing = int(2 * s)

        # 눈 흰자
        pygame.draw.ellipse(screen, (255, 255, 255),
                          (x - eye_spacing - int(2 * s), eye_y, int(3 * s), int(2 * s)))
        pygame.draw.ellipse(screen, (255, 255, 255),
                          (x + eye_spacing - int(1 * s), eye_y, int(3 * s), int(2 * s)))

        # 눈동자
        pygame.draw.circle(screen, (30, 30, 30),
                          (x - eye_spacing, eye_y + int(1 * s)), int(1 * s))
        pygame.draw.circle(screen, (30, 30, 30),
                          (x + eye_spacing, eye_y + int(1 * s)), int(1 * s))


class ColosseumFrame:
    """돔 형태 스타디움 필러 (경기장을 둘러싼 노란 관중석)"""

    # 스타디움 색상 팔레트 (Golden Bears 스타일)
    COLORS = {
        'seat_yellow': (218, 185, 77),    # 노란 좌석 (메인)
        'seat_gold': (200, 170, 60),      # 금색 좌석
        'seat_dark': (170, 145, 50),      # 어두운 노란 좌석
        'seat_light': (240, 210, 100),    # 밝은 노란 좌석
        'field_green': (60, 120, 60),     # 필드 그린
        'field_dark': (40, 90, 40),       # 어두운 필드
        'track_red': (180, 80, 60),       # 트랙 레드
        'concrete': (140, 140, 145),      # 콘크리트
        'white_line': (255, 255, 255),    # 흰색 라인
        'navy': (30, 50, 100),            # 네이비 (장식)
        'shadow': (40, 35, 30),           # 그림자
        'steel': (120, 125, 130),         # 철골 구조
        'sky': (135, 180, 220),           # 하늘색
    }

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

        # 애니메이션
        self.time = 0.0

        # 관중 NPC 생성 (많이, 빽빽하게)
        self.spectators_left = []
        self.spectators_right = []
        self._create_spectators()

        # 응원 이벤트 상태
        self.excitement_level = 0.0  # 0.0 ~ 1.0
        self.excitement_timer = 0.0

        # 캐시된 프레임
        self._frame_surface = None
        self._create_frame()

        # Wave 애니메이션 (관중 웨이브)
        self._wave_position = 0.0
        self._wave_active = False

    def _create_spectators(self):
        """관중 NPC 생성 (빽빽하게 채움)"""
        pillar_width = self.game_x

        # 관중석 배치 설정 (더 촘촘하게)
        rows = 18  # 관중 줄 수
        spectators_per_row = 5  # 줄당 관중 수

        start_y = 30  # 시작 Y 위치 (상단부터)
        row_height = (self.screen_height - start_y - 20) // rows

        # 좌측 관중석
        for row in range(rows):
            y = start_y + row * row_height
            for col in range(spectators_per_row):
                # 곡선형 배치 (경기장 테두리를 따라)
                curve_offset = int(math.sin(row / rows * math.pi) * 10)
                x = 8 + col * 14 + (row % 2) * 6 + curve_offset
                y_offset = (col % 2) * 4

                # 크기 변화 (뒤로 갈수록 약간 작게 - 원근감)
                size_scale = 0.7 + (col / spectators_per_row) * 0.3

                seed = row * 100 + col + 1000
                spectator = Spectator(x, y + y_offset, seed, size_scale)
                self.spectators_left.append(spectator)

        # 우측 관중석
        right_start_x = self.game_x + self.game_width
        for row in range(rows):
            y = start_y + row * row_height
            for col in range(spectators_per_row):
                curve_offset = int(math.sin(row / rows * math.pi) * 10)
                x = right_start_x + 8 + col * 14 + (row % 2) * 6 - curve_offset
                y_offset = (col % 2) * 4

                size_scale = 0.7 + ((spectators_per_row - col - 1) / spectators_per_row) * 0.3

                seed = row * 100 + col + 2000
                spectator = Spectator(x, y + y_offset, seed, size_scale)
                self.spectators_right.append(spectator)

    def _create_frame(self):
        """프레임 캐시 생성 (돔 형태 스타디움)"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 기본 배경 (어두운 색)
        self._frame_surface.fill(self.COLORS['shadow'])

        # 게임 영역 투명하게 (구멍 뚫기)
        pygame.draw.rect(self._frame_surface, (0, 0, 0, 0),
                        (self.game_x, self.game_y, self.game_width, self.game_height))

        # 좌측 필러 그리기 (돔 형태 관중석)
        self._draw_stadium_section(self._frame_surface, 0, self.game_x, 'left')
        # 우측 필러 그리기 (돔 형태 관중석)
        self._draw_stadium_section(self._frame_surface, self.game_x + self.game_width,
                                   self.screen_width - self.game_x - self.game_width, 'right')

        # 상단/하단 곡선 테두리 (경기장 둘레)
        self._draw_curved_border(self._frame_surface, 'top')
        self._draw_curved_border(self._frame_surface, 'bottom')

    def _draw_stadium_section(self, surface, x_start, width, side):
        """돔 형태 스타디움 관중석 그리기 (노란 좌석)"""
        seat_yellow = self.COLORS['seat_yellow']
        seat_gold = self.COLORS['seat_gold']
        seat_dark = self.COLORS['seat_dark']
        seat_light = self.COLORS['seat_light']
        concrete = self.COLORS['concrete']
        navy = self.COLORS['navy']
        steel = self.COLORS['steel']

        # 기본 배경 (콘크리트)
        pygame.draw.rect(surface, concrete, (x_start, 0, width, self.screen_height))

        # === 관중석 (계단식 노란 좌석) ===
        num_rows = 25
        row_height = self.screen_height // num_rows

        for row in range(num_rows):
            y = row * row_height

            # 곡선형 좌석 배열 (경기장 테두리를 따라 곡선)
            curve = int(math.sin((row / num_rows) * math.pi) * 15)

            if side == 'left':
                # 좌측: 오른쪽으로 볼록한 곡선
                seat_x = x_start + curve
                seat_width = width - curve
            else:
                # 우측: 왼쪽으로 볼록한 곡선
                seat_x = x_start
                seat_width = width - curve

            # 좌석 줄마다 색상 변화 (노란 톤)
            if row % 3 == 0:
                row_color = seat_gold
            elif row % 3 == 1:
                row_color = seat_yellow
            else:
                row_color = seat_light

            # 좌석 줄 그리기
            pygame.draw.rect(surface, row_color,
                            (seat_x, y, seat_width, row_height - 2))

            # 좌석 구분선 (어두운 색)
            pygame.draw.line(surface, seat_dark,
                           (seat_x, y + row_height - 2),
                           (seat_x + seat_width, y + row_height - 2), 2)

            # 좌석 개별 구분 (세로선)
            num_seats = 6
            for i in range(num_seats):
                seat_line_x = seat_x + (seat_width // num_seats) * i
                pygame.draw.line(surface, seat_dark,
                               (seat_line_x, y), (seat_line_x, y + row_height - 2), 1)

        # === 경기장 테두리 (네이비 + 금색 장식) ===
        if side == 'left':
            border_x = x_start + width - 6
        else:
            border_x = x_start

        # 세로 장식 (네이비 스트라이프)
        pygame.draw.rect(surface, navy, (border_x, 0, 6, self.screen_height))
        pygame.draw.rect(surface, seat_gold, (border_x + 2, 0, 2, self.screen_height))

        # === 상단 돔 구조 (철골 프레임) ===
        dome_height = 50
        for i in range(5):
            arc_y = 10 + i * 8
            arc_radius = width + 20 - i * 10

            if side == 'left':
                center_x = x_start + width + 10
                pygame.draw.arc(surface, steel,
                              (center_x - arc_radius, arc_y - arc_radius // 2,
                               arc_radius, arc_radius),
                              math.pi / 2, math.pi, 2)
            else:
                center_x = x_start - 10
                pygame.draw.arc(surface, steel,
                              (center_x, arc_y - arc_radius // 2,
                               arc_radius, arc_radius),
                              0, math.pi / 2, 2)

    def _draw_curved_border(self, surface, position):
        """상단/하단 곡선 테두리 (경기장 둘레)"""
        seat_yellow = self.COLORS['seat_yellow']
        seat_gold = self.COLORS['seat_gold']
        navy = self.COLORS['navy']
        track_red = self.COLORS['track_red']
        white_line = self.COLORS['white_line']

        if position == 'top':
            y = 0
            h = self.game_y
        else:
            y = self.game_y + self.game_height
            h = self.screen_height - y

        # 곡선형 관중석 (상단/하단)
        center_x = self.game_x + self.game_width // 2
        curve_height = 30

        # 곡선 좌석 배경
        for row in range(8):
            if position == 'top':
                row_y = self.game_y - 8 - row * 4
                curve_factor = row / 8
            else:
                row_y = y + row * 4
                curve_factor = row / 8

            # 색상 변화
            if row % 2 == 0:
                row_color = seat_yellow
            else:
                row_color = seat_gold

            # 곡선 형태의 좌석 줄
            for x in range(self.game_x, self.game_x + self.game_width, 4):
                # 반원형 곡선
                rel_x = (x - center_x) / (self.game_width // 2)
                curve_offset = int((1 - rel_x ** 2) * curve_height * curve_factor)

                if position == 'top':
                    pygame.draw.rect(surface, row_color, (x, row_y - curve_offset, 4, 4))
                else:
                    pygame.draw.rect(surface, row_color, (x, row_y + curve_offset, 4, 4))

        # 트랙 (경기장 바로 옆)
        if position == 'top':
            pygame.draw.rect(surface, track_red, (self.game_x, self.game_y - 4, self.game_width, 4))
            pygame.draw.line(surface, white_line,
                           (self.game_x, self.game_y - 4),
                           (self.game_x + self.game_width, self.game_y - 4), 1)
        else:
            pygame.draw.rect(surface, track_red, (self.game_x, y, self.game_width, 4))
            pygame.draw.line(surface, white_line,
                           (self.game_x, y + 4),
                           (self.game_x + self.game_width, y + 4), 1)

        # 네이비 장식 라인
        if position == 'top':
            pygame.draw.rect(surface, navy, (self.game_x, self.game_y - 6, self.game_width, 2))
        else:
            pygame.draw.rect(surface, navy, (self.game_x, y + 4, self.game_width, 2))

    def trigger_excitement(self, intensity: float = 1.0, duration: float = 2.0):
        """관중 흥분 이벤트 트리거 (득점 시 호출)"""
        self.excitement_level = min(1.0, intensity)
        self.excitement_timer = duration

    def trigger_wave(self):
        """관중 웨이브 시작"""
        self._wave_active = True
        self._wave_position = 0.0

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
            self._wave_position += dt * 200  # 웨이브 속도
            if self._wave_position > self.screen_height + 200:
                self._wave_active = False
                self._wave_position = 0.0

    def draw(self, screen: pygame.Surface):
        """프레임 그리기"""
        # 캐시된 프레임 (배경)
        if self._frame_surface:
            screen.blit(self._frame_surface, (0, 0))

        # 관중 NPC 그리기 (애니메이션)
        is_excited = self.excitement_level > 0.3

        for spectator in self.spectators_left:
            # 웨이브 애니메이션
            wave_excited = False
            if self._wave_active:
                wave_dist = abs(spectator.y - self._wave_position)
                if wave_dist < 50:
                    wave_excited = True

            spectator.draw(screen, self.time, scale=0.8, is_excited=is_excited or wave_excited)

        for spectator in self.spectators_right:
            wave_excited = False
            if self._wave_active:
                wave_dist = abs(spectator.y - self._wave_position)
                if wave_dist < 50:
                    wave_excited = True

            spectator.draw(screen, self.time, scale=0.8, is_excited=is_excited or wave_excited)

        # 응원 이펙트 (흥분 상태일 때)
        if self.excitement_level > 0.5:
            self._draw_cheer_effects(screen)

    def _draw_cheer_effects(self, screen: pygame.Surface):
        """응원 이펙트 그리기 (종이 꽃가루, 깃발 등)"""
        num_confetti = int(20 * self.excitement_level)

        for i in range(num_confetti):
            # 좌측 필러
            x = random.randint(5, self.game_x - 5)
            y = random.randint(50, self.screen_height - 50)
            size = random.randint(2, 5)
            color = random.choice([
                (255, 220, 80),   # 금색
                (60, 80, 140),    # 네이비
                (255, 255, 255),  # 흰색
                (255, 200, 50),   # 노랑
            ])
            # 반짝임 효과
            alpha = int(150 + 100 * math.sin(self.time * 10 + i))
            surf = pygame.Surface((size, size), pygame.SRCALPHA)
            surf.fill((*color, alpha))
            screen.blit(surf, (x, y))

            # 우측 필러
            x = random.randint(self.game_x + self.game_width + 5, self.screen_width - 5)
            surf2 = pygame.Surface((size, size), pygame.SRCALPHA)
            surf2.fill((*color, alpha))
            screen.blit(surf2, (x, y))

    def draw_foreground(self, screen: pygame.Surface):
        """전경 효과 (게임 위에 그려짐)"""
        # 게임 영역 주변 비네팅 효과 (약간의 그림자)
        vignette_size = 20

        # 상단 그림자
        for i in range(vignette_size):
            alpha = int(40 * (1 - i / vignette_size))
            surf = pygame.Surface((self.game_width, 1), pygame.SRCALPHA)
            surf.fill((0, 0, 0, alpha))
            screen.blit(surf, (self.game_x, self.game_y + i))

        # 하단 그림자
        for i in range(vignette_size):
            alpha = int(40 * (i / vignette_size))
            surf = pygame.Surface((self.game_width, 1), pygame.SRCALPHA)
            surf.fill((0, 0, 0, alpha))
            screen.blit(surf, (self.game_x, self.game_y + self.game_height - vignette_size + i))
