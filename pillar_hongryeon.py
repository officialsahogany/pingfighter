# -*- coding: utf-8 -*-
"""
홍련 중국 전통 필러 배경 (고퀄리티 버전)
- 게임 내 실제 스테이지 6 (홍련) = 코드 상 current_stage == 5
- 인게임 색상과 일치하는 어두운 마룬/크림슨 톤
- 그라데이션 기반 고급스러운 디자인
- 육각형 패턴, 등불, 소용돌이 장식
"""

import math
import random
import pygame


class HongryeonFrame:
    """홍련 스타일 중국 전통 필러 배경 - 고퀄리티"""

    # 인게임과 일치하는 색상 팔레트 (어두운 마룬/크림슨)
    COLORS = {
        # 배경 그라데이션 (인게임 매칭)
        'bg_darkest': (25, 8, 12),            # 가장 어두운 마룬
        'bg_dark': (45, 15, 20),              # 어두운 마룬
        'bg_mid': (65, 20, 28),               # 중간 마룬
        'bg_light': (85, 28, 35),             # 밝은 마룬

        # 인게임 붉은 톤
        'crimson_dark': (120, 35, 40),        # 어두운 크림슨
        'crimson_mid': (160, 50, 55),         # 중간 크림슨
        'crimson_light': (200, 70, 70),       # 밝은 크림슨

        # 등불/발광 색상 - 붉은색 (인게임 오렌지-레드)
        'lantern_red_core': (255, 120, 60),       # 붉은 등불 중심
        'lantern_red_glow': (255, 80, 40),        # 붉은 등불 글로우
        'lantern_red_outer': (200, 50, 30),       # 붉은 등불 외곽

        # 등불/발광 색상 - 검보라색
        'lantern_purple_core': (120, 60, 160),    # 보라 등불 중심
        'lantern_purple_glow': (80, 40, 120),     # 보라 등불 글로우
        'lantern_purple_outer': (50, 25, 80),     # 보라 등불 외곽

        # 금색 장식
        'gold_bright': (255, 200, 100),       # 밝은 금
        'gold_mid': (200, 150, 60),           # 중간 금
        'gold_dark': (150, 100, 40),          # 어두운 금

        # 소용돌이/라인 (인게임 매칭)
        'line_red': (180, 60, 50),            # 붉은 라인
        'line_glow': (220, 80, 60),           # 라인 글로우

        # 육각형 패턴
        'hex_line': (80, 30, 35),             # 육각형 테두리
        'hex_fill': (55, 18, 25),             # 육각형 내부
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

        # 필러 크기
        self.left_width = self.game_x
        self.right_width = screen_width - game_width - self.game_x

        # 애니메이션 상태
        self.time = 0.0
        self.excitement = 1.0

        # 등불
        self.lanterns = []
        self._init_lanterns()

        # 떠다니는 불씨
        self.embers = []
        self._init_embers()

        # 프레임 서피스 생성
        self._static_surface = None
        self._create_static_surface()

    def _init_lanterns(self):
        """등불 초기화"""
        # 왼쪽 필러 등불
        if self.left_width > 50:
            positions = [
                (self.left_width // 2, self.game_y + 80),
                (self.left_width // 2, self.game_y + self.game_height // 2),
                (self.left_width // 2, self.game_y + self.game_height - 80),
            ]
            for x, y in positions:
                self.lanterns.append({
                    'x': x, 'y': y,
                    'size': 35,
                    'phase': random.uniform(0, math.pi * 2),
                    'pulse_speed': random.uniform(2.0, 3.0),
                })

        # 오른쪽 필러 등불
        if self.right_width > 50:
            start_x = self.game_x + self.game_width
            positions = [
                (start_x + self.right_width // 2, self.game_y + 80),
                (start_x + self.right_width // 2, self.game_y + self.game_height // 2),
                (start_x + self.right_width // 2, self.game_y + self.game_height - 80),
            ]
            for x, y in positions:
                self.lanterns.append({
                    'x': x, 'y': y,
                    'size': 35,
                    'phase': random.uniform(0, math.pi * 2),
                    'pulse_speed': random.uniform(2.0, 3.0),
                })

    def _init_embers(self):
        """떠다니는 불씨 초기화"""
        for _ in range(25):
            side = random.choice(['left', 'right'])
            if side == 'left' and self.left_width > 20:
                x = random.randint(10, self.left_width - 10)
            elif side == 'right' and self.right_width > 20:
                x = self.game_x + self.game_width + random.randint(10, self.right_width - 10)
            else:
                continue

            self.embers.append({
                'x': x,
                'y': random.randint(0, self.screen_height),
                'base_x': x,
                'size': random.uniform(2, 5),
                'speed': random.uniform(15, 40),
                'wobble_phase': random.uniform(0, math.pi * 2),
                'wobble_speed': random.uniform(1.5, 3.0),
                'wobble_amount': random.uniform(8, 20),
                'alpha': random.randint(150, 255),
                'side': side,
            })


    def _create_static_surface(self):
        """정적 배경 서피스 생성"""
        self._static_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 그라데이션 배경
        self._draw_gradient_background(self._static_surface)

        # 육각형 패턴
        self._draw_hexagon_pattern(self._static_surface)

        # 게임 영역 테두리
        self._draw_game_border(self._static_surface)

    def _draw_gradient_background(self, surface: pygame.Surface):
        """수직 그라데이션 배경 (멘헤라 스타일)"""
        colors = [
            self.COLORS['bg_darkest'],
            self.COLORS['bg_dark'],
            self.COLORS['bg_mid'],
            self.COLORS['bg_dark'],
            self.COLORS['bg_darkest'],
        ]

        num_bands = len(colors) - 1
        band_height = self.screen_height // num_bands

        for band in range(num_bands):
            start_color = colors[band]
            end_color = colors[band + 1]
            start_y = band * band_height

            for y in range(band_height):
                ratio = y / band_height
                r = int(start_color[0] + (end_color[0] - start_color[0]) * ratio)
                g = int(start_color[1] + (end_color[1] - start_color[1]) * ratio)
                b = int(start_color[2] + (end_color[2] - start_color[2]) * ratio)

                current_y = start_y + y

                # 왼쪽 필러
                if self.left_width > 0:
                    pygame.draw.line(surface, (r, g, b, 255),
                                   (0, current_y), (self.left_width, current_y))

                # 오른쪽 필러
                if self.right_width > 0:
                    start_x = self.game_x + self.game_width
                    pygame.draw.line(surface, (r, g, b, 255),
                                   (start_x, current_y), (self.screen_width, current_y))

        # 상단 필러
        if self.game_y > 0:
            for y in range(self.game_y):
                ratio = y / max(self.game_y, 1)
                color = self.COLORS['bg_darkest']
                pygame.draw.line(surface, (*color, 255),
                               (self.game_x, y), (self.game_x + self.game_width, y))

        # 하단 필러
        bottom_start = self.game_y + self.game_height
        if bottom_start < self.screen_height:
            for y in range(bottom_start, self.screen_height):
                color = self.COLORS['bg_darkest']
                pygame.draw.line(surface, (*color, 255),
                               (self.game_x, y), (self.game_x + self.game_width, y))

    def _draw_hexagon_pattern(self, surface: pygame.Surface):
        """육각형 패턴 (인게임과 매칭)"""
        hex_size = 25
        hex_color = self.COLORS['hex_line']

        # 육각형 그리기 함수
        def draw_hexagon(cx, cy, size):
            points = []
            for i in range(6):
                angle = math.pi / 6 + i * math.pi / 3
                px = cx + size * math.cos(angle)
                py = cy + size * math.sin(angle)
                points.append((px, py))
            pygame.draw.polygon(surface, (*hex_color, 40), points, 1)

        # 왼쪽 필러에 육각형 패턴
        if self.left_width > 30:
            for row in range(self.screen_height // int(hex_size * 1.5) + 2):
                for col in range(self.left_width // int(hex_size * 1.7) + 2):
                    cx = col * hex_size * 1.7 + (hex_size * 0.85 if row % 2 else 0)
                    cy = row * hex_size * 1.5
                    if cx < self.left_width:
                        draw_hexagon(cx, cy, hex_size)

        # 오른쪽 필러에 육각형 패턴
        if self.right_width > 30:
            start_x = self.game_x + self.game_width
            for row in range(self.screen_height // int(hex_size * 1.5) + 2):
                for col in range(self.right_width // int(hex_size * 1.7) + 2):
                    cx = start_x + col * hex_size * 1.7 + (hex_size * 0.85 if row % 2 else 0)
                    cy = row * hex_size * 1.5
                    if cx < self.screen_width:
                        draw_hexagon(cx, cy, hex_size)

    def _draw_game_border(self, surface: pygame.Surface):
        """게임 영역 테두리"""
        border_color = self.COLORS['crimson_dark']
        glow_color = self.COLORS['line_red']

        # 외곽 글로우 (여러 레이어)
        for i in range(4, 0, -1):
            alpha = 30 * i
            rect = pygame.Rect(
                self.game_x - i * 2, self.game_y - i * 2,
                self.game_width + i * 4, self.game_height + i * 4
            )
            pygame.draw.rect(surface, (*glow_color, alpha), rect, 2)

        # 메인 테두리
        pygame.draw.rect(surface, (*border_color, 255),
                        (self.game_x - 2, self.game_y - 2,
                         self.game_width + 4, self.game_height + 4), 3)

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt

        # 흥분도 감쇠
        self.excitement = max(1.0, self.excitement - dt * 0.5)

        # 불씨 업데이트
        for ember in self.embers:
            ember['y'] -= ember['speed'] * dt
            ember['wobble_phase'] += ember['wobble_speed'] * dt
            ember['x'] = ember['base_x'] + math.sin(ember['wobble_phase']) * ember['wobble_amount']

            # 화면 위로 나가면 다시 아래로
            if ember['y'] < -20:
                ember['y'] = self.screen_height + random.randint(10, 50)
                if ember['side'] == 'left' and self.left_width > 20:
                    ember['base_x'] = random.randint(10, self.left_width - 10)
                elif ember['side'] == 'right' and self.right_width > 20:
                    ember['base_x'] = self.game_x + self.game_width + random.randint(10, self.right_width - 10)
                ember['x'] = ember['base_x']

    def draw(self, screen: pygame.Surface):
        """필러 배경 그리기"""
        # 정적 배경
        if self._static_surface:
            screen.blit(self._static_surface, (0, 0))

        # 호리병 등불
        self._draw_lanterns(screen)

        # 떠다니는 불씨
        self._draw_embers(screen)

        # 테두리 글로우 효과 (애니메이션)
        self._draw_animated_border_glow(screen)

    def _lerp_color(self, color1: tuple, color2: tuple, t: float) -> tuple:
        """두 색상 사이를 선형 보간"""
        t = max(0.0, min(1.0, t))
        return (
            int(color1[0] + (color2[0] - color1[0]) * t),
            int(color1[1] + (color2[1] - color1[1]) * t),
            int(color1[2] + (color2[2] - color1[2]) * t),
        )

    def _draw_lanterns(self, screen: pygame.Surface):
        """호리병/매화병 스타일 등불 그리기 - 검보라색 <-> 붉은색 그라데이션 변화"""
        for lantern in self.lanterns:
            # 밝기 맥동
            pulse = math.sin(self.time * lantern['pulse_speed'] + lantern['phase'])
            intensity = 0.7 + 0.3 * pulse
            size = lantern['size']
            x, y = int(lantern['x']), int(lantern['y'])

            # 색상 변화 (천천히 보라 <-> 빨강, 각 등불마다 다른 위상)
            # 약 8초 주기로 색상 순환
            color_cycle = (math.sin(self.time * 0.4 + lantern['phase']) + 1) * 0.5

            # 현재 색상 계산 (보라 -> 빨강 보간)
            current_core = self._lerp_color(
                self.COLORS['lantern_purple_core'],
                self.COLORS['lantern_red_core'],
                color_cycle
            )
            current_glow = self._lerp_color(
                self.COLORS['lantern_purple_glow'],
                self.COLORS['lantern_red_glow'],
                color_cycle
            )
            current_outer = self._lerp_color(
                self.COLORS['lantern_purple_outer'],
                self.COLORS['lantern_red_outer'],
                color_cycle
            )

            # 금색 테두리/장식 색상
            gold_dark = self._lerp_color(
                (120, 100, 140),  # 보라색일 때 어두운 보라금
                self.COLORS['gold_dark'],
                color_cycle
            )
            gold_color = self._lerp_color(
                (180, 150, 200),  # 보라색일 때 연한 보라금
                self.COLORS['gold_mid'],
                color_cycle
            )
            gold_bright = self._lerp_color(
                (220, 200, 255),  # 보라색일 때 밝은 라벤더
                self.COLORS['gold_bright'],
                color_cycle
            )

            # === 외부 글로우 (부드러운 빛 퍼짐) ===
            for r in range(8, 0, -1):
                glow_size = size + r * 15
                alpha = int(18 * intensity * (9 - r) / 8)
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*current_glow, alpha),
                                 (glow_size, glow_size), glow_size)
                screen.blit(glow_surf, (x - glow_size, y - glow_size))

            # === 호리병 본체 (곡선형 실루엣) ===
            vase_height = int(size * 2.8)
            vase_top = y - vase_height // 2
            segments = 32  # 더 부드러운 곡선

            def get_vase_width(t):
                """호리병 곡선 계산 - 더 정교한 형태"""
                if t < 0.08:  # 입구 (좁게 시작)
                    return 0.22 + t * 2.0
                elif t < 0.15:  # 목 (살짝 넓어짐)
                    return 0.38 + (t - 0.08) * 1.2
                elif t < 0.25:  # 어깨 (급격히 넓어짐)
                    return 0.46 + (t - 0.15) * 5.0
                elif t < 0.7:  # 몸통 (가장 넓은 부분, 곡선)
                    mid_t = (t - 0.25) / 0.45
                    return 0.96 + 0.18 * math.sin(mid_t * math.pi)
                else:  # 바닥 (좁아짐)
                    return 1.14 - (t - 0.7) * 2.0

            # 호리병 외곽선
            vase_points = []
            for i in range(segments + 1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.55 * max(0.18, get_vase_width(t)))
                vase_points.append((x - half_width, seg_y))
            for i in range(segments, -1, -1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.55 * max(0.18, get_vase_width(t)))
                vase_points.append((x + half_width, seg_y))

            # 1. 외곽 그림자 (3D 효과)
            shadow_points = [(p[0] + 3, p[1] + 2) for p in vase_points]
            pygame.draw.polygon(screen, (20, 10, 15), shadow_points)

            # 2. 외곽 (가장 어두운)
            pygame.draw.polygon(screen, current_outer, vase_points)

            # 3. 중간층 (그라데이션)
            mid_points = []
            for i in range(segments + 1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.48 * max(0.15, get_vase_width(t)))
                mid_points.append((x - half_width, seg_y))
            for i in range(segments, -1, -1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.48 * max(0.15, get_vase_width(t)))
                mid_points.append((x + half_width, seg_y))
            pygame.draw.polygon(screen, current_glow, mid_points)

            # 4. 내부 발광층
            inner_points = []
            for i in range(segments + 1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.38 * max(0.12, get_vase_width(t)))
                inner_points.append((x - half_width, seg_y))
            for i in range(segments, -1, -1):
                t = i / segments
                seg_y = vase_top + int(t * vase_height)
                half_width = int(size * 0.38 * max(0.12, get_vase_width(t)))
                inner_points.append((x + half_width, seg_y))

            # 발광 블렌딩
            inner_color = self._lerp_color(current_glow, current_core, 0.5)
            pygame.draw.polygon(screen, inner_color, inner_points)

            # 5. 중심 코어 발광
            core_y = y + int(size * 0.25)
            core_width = int(size * 0.28)
            core_height = int(size * 0.7)
            for i in range(3, 0, -1):
                core_surf = pygame.Surface((core_width * 2 + i * 8, core_height + i * 6), pygame.SRCALPHA)
                pygame.draw.ellipse(core_surf, (*current_core, 50 + i * 20),
                                  (0, 0, core_width * 2 + i * 8, core_height + i * 6))
                screen.blit(core_surf, (x - core_width - i * 4, core_y - core_height // 2 - i * 3))

            # === 정교한 금색 장식 ===
            # 입구 테두리 (립)
            lip_y = vase_top + int(vase_height * 0.02)
            lip_width = int(size * 0.15)
            # 립 외곽
            pygame.draw.ellipse(screen, gold_dark,
                              (x - lip_width - 4, lip_y - 4, (lip_width + 4) * 2, 8))
            # 립 내부
            pygame.draw.ellipse(screen, gold_color,
                              (x - lip_width - 2, lip_y - 2, (lip_width + 2) * 2, 5))
            # 립 하이라이트
            pygame.draw.ellipse(screen, gold_bright,
                              (x - lip_width + 2, lip_y - 1, lip_width, 2))

            # 목 장식 링 (이중)
            neck_y1 = vase_top + int(vase_height * 0.10)
            neck_y2 = vase_top + int(vase_height * 0.14)
            neck_width = int(size * 0.22)
            pygame.draw.ellipse(screen, gold_dark,
                              (x - neck_width - 2, neck_y1 - 2, (neck_width + 2) * 2, 4))
            pygame.draw.ellipse(screen, gold_color,
                              (x - neck_width, neck_y1 - 1, neck_width * 2, 3))
            pygame.draw.ellipse(screen, gold_dark,
                              (x - neck_width - 1, neck_y2 - 2, (neck_width + 1) * 2, 4))
            pygame.draw.ellipse(screen, gold_color,
                              (x - neck_width + 1, neck_y2 - 1, (neck_width - 1) * 2, 3))

            # 어깨 장식 (넓은 금테)
            shoulder_y = vase_top + int(vase_height * 0.24)
            shoulder_width = int(size * 0.52)
            # 어깨 그림자
            pygame.draw.ellipse(screen, gold_dark,
                              (x - shoulder_width - 2, shoulder_y - 3, (shoulder_width + 2) * 2, 7))
            # 어깨 메인
            pygame.draw.ellipse(screen, gold_color,
                              (x - shoulder_width, shoulder_y - 2, shoulder_width * 2, 5))
            # 어깨 하이라이트
            pygame.draw.ellipse(screen, gold_bright,
                              (x - shoulder_width + 4, shoulder_y - 1, shoulder_width - 8, 2))

            # 몸통 중앙 장식 띠
            mid_band_y = y + int(size * 0.15)
            mid_band_width = int(size * 0.58)
            pygame.draw.ellipse(screen, gold_dark,
                              (x - mid_band_width, mid_band_y - 2, mid_band_width * 2, 4))
            pygame.draw.ellipse(screen, gold_color,
                              (x - mid_band_width + 2, mid_band_y - 1, (mid_band_width - 2) * 2, 2))

            # 바닥 받침대 (다층)
            bottom_y = vase_top + vase_height - 8
            bottom_width = int(size * 0.38)
            # 받침대 베이스
            pygame.draw.ellipse(screen, gold_dark,
                              (x - bottom_width - 4, bottom_y, (bottom_width + 4) * 2, 10))
            # 받침대 상단
            pygame.draw.ellipse(screen, gold_color,
                              (x - bottom_width - 2, bottom_y + 1, (bottom_width + 2) * 2, 6))
            # 받침대 하이라이트
            pygame.draw.ellipse(screen, gold_bright,
                              (x - bottom_width + 4, bottom_y + 2, bottom_width - 4, 2))

            # === 병 표면 문양 (매화/구름) ===
            pattern_color = self._lerp_color(
                (100, 80, 130, 60),
                (180, 100, 80, 60),
                color_cycle
            )
            # 매화 문양 (단순화된 점 패턴)
            pattern_y1 = y - int(size * 0.1)
            pattern_y2 = y + int(size * 0.4)
            for py in [pattern_y1, pattern_y2]:
                for px_offset in [-8, 0, 8]:
                    pygame.draw.circle(screen, (*pattern_color[:3], 40),
                                     (x + px_offset, py), 3)

            # === 불꽃 효과 (병 입구에서 나오는 빛) ===
            flame_base_y = vase_top + 2
            flame_height = int(size * 0.6 * intensity)
            flame_wobble = math.sin(self.time * 6 + lantern['phase']) * 4
            flame_wobble2 = math.sin(self.time * 9 + lantern['phase'] + 1) * 2

            # 외부 글로우 (가장 넓은)
            for f in range(4, 0, -1):
                flame_w = 12 + f * 5
                flame_h = flame_height + f * 10
                flame_surf = pygame.Surface((flame_w * 2, flame_h), pygame.SRCALPHA)
                # 불꽃 형태 (여러 삼각형 합성)
                main_points = [
                    (flame_w + flame_wobble, 0),
                    (flame_w - flame_w * 0.7, flame_h),
                    (flame_w + flame_w * 0.7, flame_h),
                ]
                pygame.draw.polygon(flame_surf, (*current_glow, 40 // f), main_points)
                screen.blit(flame_surf, (x - flame_w, flame_base_y - flame_h))

            # 메인 불꽃 (3층)
            # 외부 불꽃
            outer_flame = [
                (x + flame_wobble, flame_base_y - flame_height),
                (x - 10, flame_base_y),
                (x + 10, flame_base_y),
            ]
            pygame.draw.polygon(screen, current_glow, outer_flame)

            # 중간 불꽃
            mid_flame = [
                (x + flame_wobble * 0.7, flame_base_y - flame_height * 0.85),
                (x - 7, flame_base_y),
                (x + 7, flame_base_y),
            ]
            pygame.draw.polygon(screen, current_core, mid_flame)

            # 내부 불꽃 (가장 밝은)
            inner_flame = [
                (x + flame_wobble2, flame_base_y - flame_height * 0.6),
                (x - 4, flame_base_y),
                (x + 4, flame_base_y),
            ]
            pygame.draw.polygon(screen, gold_bright, inner_flame)

            # 불꽃 스파크 (작은 불씨들)
            for i in range(3):
                spark_x = x + flame_wobble + random.randint(-6, 6)
                spark_y = flame_base_y - flame_height * 0.3 - i * 8
                spark_size = 2 - i * 0.5
                if spark_size > 0:
                    pygame.draw.circle(screen, gold_bright, (int(spark_x), int(spark_y)), int(spark_size))

            # === 하이라이트 (3D 입체감) ===
            # 왼쪽 반사광 (세로 하이라이트)
            highlight_x = x - int(size * 0.3)
            highlight_y = y - int(size * 0.2)
            highlight_surf = pygame.Surface((8, int(size * 1.2)), pygame.SRCALPHA)
            for i in range(8):
                alpha = 60 - i * 8
                if alpha > 0:
                    pygame.draw.line(highlight_surf, (*gold_bright, alpha),
                                   (i, 0), (i, int(size * 1.2)))
            screen.blit(highlight_surf, (highlight_x, highlight_y))

            # 오른쪽 림라이트 (미세한)
            rim_x = x + int(size * 0.25)
            rim_surf = pygame.Surface((4, int(size * 0.8)), pygame.SRCALPHA)
            for i in range(4):
                alpha = 30 - i * 8
                if alpha > 0:
                    pygame.draw.line(rim_surf, (*gold_bright, alpha),
                                   (3 - i, 0), (3 - i, int(size * 0.8)))
            screen.blit(rim_surf, (rim_x, y))

    def _draw_embers(self, screen: pygame.Surface):
        """떠다니는 불씨 그리기 - 등불과 동기화된 색상 변화"""
        for ember in self.embers:
            x, y = int(ember['x']), int(ember['y'])
            size = ember['size']

            # 색상 변화 (등불과 비슷하게, 위치에 따른 위상 차이)
            color_cycle = (math.sin(self.time * 0.4 + ember['wobble_phase'] * 0.5) + 1) * 0.5

            # 현재 색상 계산
            current_glow = self._lerp_color(
                self.COLORS['lantern_purple_glow'],
                self.COLORS['lantern_red_glow'],
                color_cycle
            )
            current_core = self._lerp_color(
                self.COLORS['lantern_purple_core'],
                self.COLORS['lantern_red_core'],
                color_cycle
            )

            # 불씨 (다이아몬드 모양, 인게임 스타일)
            points = [
                (x, y - size * 1.5),  # 위
                (x + size * 0.6, y),   # 오른쪽
                (x, y + size * 0.8),   # 아래
                (x - size * 0.6, y),   # 왼쪽
            ]

            # 글로우
            glow_surf = pygame.Surface((int(size * 4), int(size * 4)), pygame.SRCALPHA)
            glow_center = (int(size * 2), int(size * 2))
            pygame.draw.circle(glow_surf, (*current_glow, 40),
                             glow_center, int(size * 1.5))
            screen.blit(glow_surf, (x - size * 2, y - size * 2))

            # 본체
            pygame.draw.polygon(screen, current_core, points)

    def _draw_animated_border_glow(self, screen: pygame.Surface):
        """애니메이션 테두리 글로우"""
        pulse = (math.sin(self.time * 2) + 1) * 0.5
        intensity = 0.3 + pulse * 0.4 * self.excitement

        glow_width = int(6 * intensity)
        if glow_width > 0:
            alpha = int(50 * intensity)
            color = (*self.COLORS['line_glow'], alpha)

            # 좌측 글로우
            glow_surf = pygame.Surface((glow_width, self.game_height), pygame.SRCALPHA)
            glow_surf.fill(color)
            screen.blit(glow_surf, (self.game_x - glow_width, self.game_y))

            # 우측 글로우
            screen.blit(glow_surf, (self.game_x + self.game_width, self.game_y))

    def trigger_excitement(self, level: float = 1.5):
        """흥분도 트리거"""
        self.excitement = min(3.0, self.excitement + level)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.__init__(screen_width, screen_height, game_width, game_height)


# 전역 인스턴스
_hongryeon_bg = None


def init_hongryeon_background(screen_width: int, screen_height: int,
                              game_width: int, game_height: int) -> HongryeonFrame:
    """홍련 배경 초기화"""
    global _hongryeon_bg
    _hongryeon_bg = HongryeonFrame(screen_width, screen_height, game_width, game_height)
    return _hongryeon_bg


def get_hongryeon_background() -> HongryeonFrame:
    """홍련 배경 인스턴스 반환"""
    return _hongryeon_bg
