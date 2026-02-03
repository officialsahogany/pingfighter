# -*- coding: utf-8 -*-
"""
고대 투기장 스타일 필러 배경 (Stage 30 - Colosseum Arena)
로마 콜로세움 테마: 돔 형태 경기장, 관중석, 응원하는 관중 NPC
"""

import math
import random
import pygame


class Spectator:
    """관중 NPC (광장 주민 NPC 스타일)"""

    # 다양한 피부색
    SKIN_TONES = [
        (255, 224, 189),  # 밝은 피부
        (255, 205, 148),  # 중간 밝은 피부
        (234, 192, 134),  # 올리브
        (198, 134, 66),   # 중간 어두운 피부
        (141, 85, 36),    # 어두운 피부
        (255, 219, 172),  # 복숭아빛
    ]

    # 다양한 옷 색상
    BODY_COLORS = [
        (180, 60, 60),    # 빨강
        (60, 100, 180),   # 파랑
        (60, 150, 80),    # 초록
        (180, 150, 60),   # 노랑
        (150, 80, 150),   # 보라
        (180, 100, 60),   # 주황
        (100, 100, 100),  # 회색
        (60, 60, 80),     # 남색
        (180, 120, 80),   # 갈색
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

    def __init__(self, x: float, y: float, seed: int):
        self.x = x
        self.y = y
        self.seed = seed

        # 랜덤 특성 (시드 기반)
        random.seed(seed)
        self.skin_color = random.choice(self.SKIN_TONES)
        self.body_color = random.choice(self.BODY_COLORS)
        self.hair_color = random.choice(self.HAIR_COLORS)

        # 얼굴형과 머리 스타일
        self.face_type = random.choice(["round", "oval", "square"])
        self.hair_style = random.choice(["short", "medium", "long", "bald"])
        self.has_hat = random.random() < 0.15  # 15% 확률로 모자

        # 애니메이션 오프셋 (개인별 차이)
        self.anim_offset = random.uniform(0, math.pi * 2)
        self.cheer_speed = random.uniform(0.8, 1.2)
        self.arm_length = random.uniform(0.8, 1.2)

        # 상태
        self.is_cheering = False
        self.cheer_intensity = random.uniform(0.5, 1.0)  # 응원 강도

        random.seed()  # 시드 리셋

    def draw(self, screen: pygame.Surface, time: float, scale: float = 1.0, is_excited: bool = False):
        """관중 그리기 (광장 주민 NPC 스타일)"""
        # 스케일 적용
        s = scale

        # 응원 애니메이션
        cheer_phase = time * 4 * self.cheer_speed + self.anim_offset

        if is_excited:
            # 흥분 상태: 더 격렬한 응원
            bob = int(abs(math.sin(cheer_phase * 2)) * 3 * s)
            arm_raise = int(math.sin(cheer_phase) * 4 * s * self.arm_length)
        else:
            # 평소 상태: 가벼운 움직임
            bob = int(abs(math.sin(cheer_phase * 0.5)) * 1 * s)
            arm_raise = int(math.sin(cheer_phase * 0.3) * 2 * s * self.arm_length)

        x = int(self.x)
        y = int(self.y) - bob

        # 색상 계산
        body_dark = tuple(max(0, c - 30) for c in self.body_color)
        skin_dark = tuple(max(0, c - 20) for c in self.skin_color)

        # === 몸통 (상체만 보임 - 관중석에 앉아있으므로) ===
        body_w = int(10 * s)
        body_h = int(12 * s)
        body_x = x - body_w // 2
        body_y = y

        # 몸통 그리기
        pygame.draw.rect(screen, self.body_color,
                        (body_x, body_y, body_w, body_h), border_radius=int(2 * s))
        # 음영
        pygame.draw.rect(screen, body_dark,
                        (body_x, body_y, int(2 * s), body_h), border_radius=int(1 * s))

        # === 팔 (응원 애니메이션) ===
        arm_w = int(3 * s)
        arm_h = int(8 * s)

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
        neck_w = int(4 * s)
        neck_h = int(3 * s)
        neck_x = x - neck_w // 2
        neck_y = body_y - neck_h + int(2 * s)
        pygame.draw.rect(screen, self.skin_color, (neck_x, neck_y, neck_w, neck_h + int(2 * s)))

        # === 머리 ===
        if self.face_type == "round":
            head_w, head_h = int(10 * s), int(10 * s)
        elif self.face_type == "oval":
            head_w, head_h = int(9 * s), int(11 * s)
        else:  # square
            head_w, head_h = int(10 * s), int(9 * s)

        # 머리 흔들림 (응원 중)
        head_sway = int(math.sin(cheer_phase * 1.5) * 1 * s) if is_excited else 0

        head_x = x - head_w // 2 + head_sway
        head_y = neck_y - head_h + int(3 * s)

        # 얼굴
        pygame.draw.ellipse(screen, self.skin_color, (head_x, head_y, head_w, head_h))

        # === 머리카락 ===
        if self.hair_style == "short":
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(1 * s), head_y - int(1 * s), head_w + int(2 * s), head_h // 2 + int(3 * s)))
        elif self.hair_style == "medium":
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(2 * s), head_y - int(2 * s), head_w + int(4 * s), head_h // 2 + int(4 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(2 * s), head_y + int(2 * s), int(4 * s), int(6 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x + head_w - int(2 * s), head_y + int(2 * s), int(4 * s), int(6 * s)))
        elif self.hair_style == "long":
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(2 * s), head_y - int(2 * s), head_w + int(4 * s), head_h // 2 + int(4 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x - int(3 * s), head_y + int(2 * s), int(5 * s), int(10 * s)))
            pygame.draw.ellipse(screen, self.hair_color,
                              (head_x + head_w - int(2 * s), head_y + int(2 * s), int(5 * s), int(10 * s)))
        # bald는 머리카락 안 그림

        # 모자 (있는 경우)
        if self.has_hat:
            hat_color = random.Random(self.seed + 100).choice([(180, 60, 60), (60, 100, 180), (200, 160, 60)])
            pygame.draw.ellipse(screen, hat_color,
                              (head_x - int(2 * s), head_y - int(2 * s), head_w + int(4 * s), int(6 * s)))
            pygame.draw.rect(screen, hat_color,
                            (head_x - int(4 * s), head_y + int(2 * s), head_w + int(8 * s), int(3 * s)))

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
    """고대 투기장 스타일 액자 테두리 (돔 경기장 + 관중석)"""

    # 콜로세움 색상 팔레트
    COLORS = {
        'stone': (140, 130, 115),       # 석조 색상
        'dark_stone': (90, 85, 75),     # 어두운 돌
        'light_stone': (180, 170, 155), # 밝은 돌
        'gold': (200, 160, 60),         # 금색 (장식)
        'bronze': (180, 120, 60),       # 청동색
        'sand': (194, 158, 108),        # 모래색
        'torch_orange': (255, 140, 40), # 횃불 주황
        'torch_yellow': (255, 220, 100),# 횃불 노랑
        'shadow': (40, 35, 30),         # 그림자
        'laurel': (80, 120, 60),        # 월계수 녹색
        'sky': (135, 180, 220),         # 하늘색 (돔 창문)
        'seat_wood': (120, 80, 50),     # 관중석 나무색
        'seat_dark': (80, 50, 30),      # 관중석 어두운 나무
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

        # 횃불
        self.torches = self._create_torches()

        # 먼지 파티클
        self.dust_particles = []
        self._create_dust_particles()

        # 관중 NPC 생성
        self.spectators_left = []
        self.spectators_right = []
        self._create_spectators()

        # 응원 이벤트 상태
        self.excitement_level = 0.0  # 0.0 ~ 1.0
        self.excitement_timer = 0.0

        # 캐시된 프레임
        self._frame_surface = None
        self._create_frame()

        # 검투사 실루엣 애니메이션
        self._gladiator_animation_timer = 0.0

    def _create_torches(self):
        """횃불 생성 (상단에만 배치)"""
        torches = []
        # 좌측 필러 횃불
        left_x = self.game_x // 2
        # 우측 필러 횃불
        right_x = self.game_x + self.game_width + (self.screen_width - self.game_x - self.game_width) // 2

        positions = [
            (left_x, 80),
            (right_x, 80),
        ]

        for x, y in positions:
            torches.append({
                'x': x,
                'y': y,
                'flicker_phase': random.uniform(0, math.pi * 2),
                'intensity': random.uniform(0.8, 1.0),
                'flame_height': random.uniform(25, 35),
            })
        return torches

    def _create_dust_particles(self):
        """먼지 파티클 생성"""
        for _ in range(10):
            side = random.choice(['left', 'right'])
            if side == 'left':
                x = random.randint(5, self.game_x - 5)
            else:
                x = random.randint(self.game_x + self.game_width + 5, self.screen_width - 5)

            self.dust_particles.append({
                'x': x,
                'y': random.randint(50, self.screen_height - 50),
                'vx': random.uniform(-0.15, 0.15),
                'vy': random.uniform(-0.2, 0.1),
                'size': random.uniform(1, 2),
                'alpha': random.randint(20, 50),
                'life': random.randint(200, 400),
                'side': side
            })

    def _create_spectators(self):
        """관중 NPC 생성"""
        pillar_width = self.game_x

        # 관중 배치 설정
        rows = 12  # 관중 줄 수
        spectators_per_row = 3  # 줄당 관중 수

        start_y = 120  # 시작 Y 위치 (돔 아래)
        row_height = 50  # 줄 간격

        # 좌측 관중석
        for row in range(rows):
            y = start_y + row * row_height
            for col in range(spectators_per_row):
                # 계단식 배치 (뒤로 갈수록 높이)
                x = 10 + col * 22 + (row % 2) * 8
                # 줄마다 약간 다른 Y 오프셋
                y_offset = (col % 2) * 5

                seed = row * 100 + col + 1000
                spectator = Spectator(x, y + y_offset, seed)
                self.spectators_left.append(spectator)

        # 우측 관중석
        right_start_x = self.game_x + self.game_width
        for row in range(rows):
            y = start_y + row * row_height
            for col in range(spectators_per_row):
                x = right_start_x + 10 + col * 22 + (row % 2) * 8
                y_offset = (col % 2) * 5

                seed = row * 100 + col + 2000
                spectator = Spectator(x, y + y_offset, seed)
                self.spectators_right.append(spectator)

    def _create_frame(self):
        """프레임 캐시 생성"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 배경 (어두운 석조)
        self._frame_surface.fill(self.COLORS['dark_stone'])

        # 게임 영역 투명하게 (구멍 뚫기)
        pygame.draw.rect(self._frame_surface, (0, 0, 0, 0),
                        (self.game_x, self.game_y, self.game_width, self.game_height))

        # 좌측 필러 그리기 (돔 + 관중석)
        self._draw_pillar_with_dome(self._frame_surface, 0, self.game_x, 'left')
        # 우측 필러 그리기 (돔 + 관중석)
        self._draw_pillar_with_dome(self._frame_surface, self.game_x + self.game_width,
                                    self.screen_width - self.game_x - self.game_width, 'right')

        # 상단/하단 테두리
        self._draw_horizontal_border(self._frame_surface, 'top')
        self._draw_horizontal_border(self._frame_surface, 'bottom')

    def _draw_pillar_with_dome(self, surface, x_start, width, side):
        """돔 형태 경기장과 관중석 그리기"""
        stone = self.COLORS['stone']
        dark = self.COLORS['dark_stone']
        light = self.COLORS['light_stone']
        gold = self.COLORS['gold']
        sky = self.COLORS['sky']
        seat_wood = self.COLORS['seat_wood']
        seat_dark = self.COLORS['seat_dark']

        # 기본 배경 (어두운 색)
        pygame.draw.rect(surface, dark, (x_start, 0, width, self.screen_height))

        # === 돔 상단 (반원형 천장) ===
        dome_height = 100
        dome_center_x = x_start + width // 2

        # 돔 아치 배경 (하늘색 - 열린 천장 느낌)
        pygame.draw.ellipse(surface, sky,
                           (x_start - width // 2, -dome_height // 2, width * 2, dome_height))

        # 돔 테두리 (석조 아치)
        for i in range(5):
            arch_color = tuple(min(255, c + i * 10) for c in stone)
            pygame.draw.arc(surface, arch_color,
                           (x_start - width // 2 + i * 2, -dome_height // 2 + i * 2,
                            width * 2 - i * 4, dome_height - i * 4),
                           0, math.pi, 3)

        # 돔 장식 라인
        pygame.draw.arc(surface, gold,
                       (x_start - width // 4, 10, width * 1.5, dome_height - 20),
                       0, math.pi, 2)

        # === 관중석 (계단식 배치) ===
        seat_start_y = dome_height + 10
        num_rows = 12
        row_height = (self.screen_height - seat_start_y - 30) // num_rows

        for row in range(num_rows):
            y = seat_start_y + row * row_height

            # 관중석 단 (나무 벤치)
            seat_y = y + row_height - 15
            pygame.draw.rect(surface, seat_wood,
                            (x_start + 5, seat_y, width - 10, 12), border_radius=2)
            pygame.draw.rect(surface, seat_dark,
                            (x_start + 5, seat_y, width - 10, 3), border_radius=1)

            # 기둥 간격 구분선 (좌석 구분)
            if row % 3 == 0:
                pygame.draw.line(surface, dark,
                               (x_start + 3, y), (x_start + 3, y + row_height), 2)
                pygame.draw.line(surface, dark,
                               (x_start + width - 3, y), (x_start + width - 3, y + row_height), 2)

        # === 경기장 테두리 (금색 장식) ===
        # 게임 영역과 맞닿는 부분
        if side == 'left':
            border_x = x_start + width - 8
        else:
            border_x = x_start

        # 세로 장식 기둥
        pygame.draw.rect(surface, light, (border_x, 0, 8, self.screen_height))
        pygame.draw.rect(surface, gold, (border_x + 2, 0, 4, self.screen_height))

        # 상단 장식
        pygame.draw.rect(surface, gold, (x_start, dome_height - 5, width, 8))
        pygame.draw.rect(surface, light, (x_start, dome_height, width, 3))

    def _draw_horizontal_border(self, surface, position):
        """상단/하단 테두리 그리기"""
        stone = self.COLORS['stone']
        gold = self.COLORS['gold']
        dark = self.COLORS['dark_stone']

        if position == 'top':
            y = 0
            h = self.game_y
        else:
            y = self.game_y + self.game_height
            h = self.screen_height - y

        # 기본 배경
        pygame.draw.rect(surface, stone, (self.game_x, y, self.game_width, h))

        # 금색 라인
        if position == 'top':
            pygame.draw.rect(surface, gold, (self.game_x, self.game_y - 5, self.game_width, 5))
            pygame.draw.rect(surface, dark, (self.game_x, self.game_y - 8, self.game_width, 3))
        else:
            pygame.draw.rect(surface, gold, (self.game_x, y, self.game_width, 5))
            pygame.draw.rect(surface, dark, (self.game_x, y + 5, self.game_width, 3))

    def trigger_excitement(self, intensity: float = 1.0, duration: float = 2.0):
        """관중 흥분 이벤트 트리거 (득점 시 호출)"""
        self.excitement_level = min(1.0, intensity)
        self.excitement_timer = duration

    def update(self, dt: float, player_rect=None):
        """업데이트"""
        self.time += dt
        self._gladiator_animation_timer += dt

        # 흥분 상태 감소
        if self.excitement_timer > 0:
            self.excitement_timer -= dt
            if self.excitement_timer <= 0:
                self.excitement_level = max(0, self.excitement_level - dt * 0.5)
        else:
            self.excitement_level = max(0, self.excitement_level - dt * 0.3)

        # 횃불 업데이트
        for torch in self.torches:
            torch['intensity'] = 0.7 + 0.3 * math.sin(self.time * 8 + torch['flicker_phase'])
            torch['flame_height'] = 28 + 7 * math.sin(self.time * 6 + torch['flicker_phase'])

        # 먼지 파티클 업데이트
        for particle in self.dust_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1

            if particle['life'] <= 0:
                # 재생성
                side = particle['side']
                if side == 'left':
                    particle['x'] = random.randint(5, self.game_x - 5)
                else:
                    particle['x'] = random.randint(self.game_x + self.game_width + 5,
                                                   self.screen_width - 5)
                particle['y'] = random.randint(50, self.screen_height - 50)
                particle['life'] = random.randint(200, 400)
                particle['alpha'] = random.randint(20, 50)

    def draw(self, screen: pygame.Surface):
        """프레임 그리기"""
        # 캐시된 프레임 (배경)
        if self._frame_surface:
            screen.blit(self._frame_surface, (0, 0))

        # 관중 NPC 그리기 (애니메이션)
        is_excited = self.excitement_level > 0.3

        for spectator in self.spectators_left:
            spectator.draw(screen, self.time, scale=0.9, is_excited=is_excited)

        for spectator in self.spectators_right:
            spectator.draw(screen, self.time, scale=0.9, is_excited=is_excited)

        # 횃불 (애니메이션)
        for torch in self.torches:
            self._draw_torch(screen, torch)

        # 먼지 파티클
        for particle in self.dust_particles:
            color = (180, 160, 130)
            pygame.draw.circle(screen, color, (int(particle['x']), int(particle['y'])),
                             int(particle['size']))

        # 응원 이펙트 (흥분 상태일 때)
        if self.excitement_level > 0.5:
            self._draw_cheer_effects(screen)

    def _draw_cheer_effects(self, screen: pygame.Surface):
        """응원 이펙트 그리기 (종이 꽃가루 등)"""
        num_confetti = int(15 * self.excitement_level)

        for i in range(num_confetti):
            # 좌측 필러
            x = random.randint(5, self.game_x - 5)
            y = random.randint(100, self.screen_height - 100)
            size = random.randint(2, 4)
            color = random.choice([
                (255, 200, 50),   # 금색
                (255, 100, 100),  # 빨강
                (100, 200, 255),  # 파랑
                (255, 255, 255),  # 흰색
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

    def _draw_torch(self, screen, torch):
        """횃불 그리기"""
        tx, ty = int(torch['x']), int(torch['y'])
        intensity = torch['intensity']
        flame_h = int(torch['flame_height'])

        # 횃불 받침대
        holder_color = (60, 50, 40)
        pygame.draw.rect(screen, holder_color, (tx - 5, ty, 10, 25))

        # 외부 불꽃
        outer_color = (255, int(120 * intensity), 0)
        points = [
            (tx, ty),
            (tx - 10, ty - flame_h // 2),
            (tx, ty - flame_h),
            (tx + 10, ty - flame_h // 2)
        ]
        pygame.draw.polygon(screen, outer_color, points)

        # 내부 불꽃
        inner_color = (255, int(220 * intensity), int(100 * intensity))
        inner_h = int(flame_h * 0.6)
        inner_points = [
            (tx, ty - 5),
            (tx - 5, ty - flame_h // 3),
            (tx, ty - inner_h),
            (tx + 5, ty - flame_h // 3)
        ]
        pygame.draw.polygon(screen, inner_color, inner_points)

        # 글로우 효과
        glow_radius = int(40 * intensity)
        glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        for r in range(glow_radius, 0, -3):
            alpha = int(25 * (r / glow_radius) * intensity)
            pygame.draw.circle(glow_surf, (255, 150, 50, alpha),
                             (glow_radius, glow_radius), r)
        screen.blit(glow_surf, (tx - glow_radius, ty - flame_h - glow_radius),
                   special_flags=pygame.BLEND_ADD)

    def draw_foreground(self, screen: pygame.Surface):
        """전경 효과 (게임 위에 그려짐)"""
        # 게임 영역 주변 비네팅 효과
        vignette_size = 30

        # 상단 그림자
        for i in range(vignette_size):
            alpha = int(60 * (1 - i / vignette_size))
            pygame.draw.line(screen, (0, 0, 0),
                           (self.game_x, self.game_y + i),
                           (self.game_x + self.game_width, self.game_y + i))

        # 하단 그림자
        for i in range(vignette_size):
            alpha = int(60 * (i / vignette_size))
            pygame.draw.line(screen, (0, 0, 0),
                           (self.game_x, self.game_y + self.game_height - vignette_size + i),
                           (self.game_x + self.game_width, self.game_y + self.game_height - vignette_size + i))
