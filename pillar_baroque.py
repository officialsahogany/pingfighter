# -*- coding: utf-8 -*-
"""
메카닉 메탈 스타일 액자 필러 배경 (메인 메뉴용)
게임 화면 주변을 메카닉/로봇 스타일의 금속 액자 테두리로 장식
1초 동안 멋지게 조립되면서 생성되는 애니메이션 효과
"""

import math
import os
import sys
import random
import pygame
from typing import List, Optional


def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


class BaroqueFrame:
    """메카닉 메탈 스타일 액자 - 필러 영역에 렌더링"""

    # 색상 팔레트 (메탈/메카닉)
    COLORS = {
        # 메인 메탈 - 건메탈/다크 스틸
        'metal_light': (180, 185, 195),
        'metal': (120, 125, 135),
        'metal_dark': (70, 75, 85),
        'metal_shadow': (40, 42, 50),
        # 하이라이트 - 크롬/실버
        'chrome': (220, 225, 235),
        'chrome_bright': (245, 248, 255),
        # 액센트 - 시안 LED
        'led_cyan': (0, 220, 255),
        'led_cyan_dim': (0, 120, 160),
        # 액센트 - 오렌지/레드 LED
        'led_orange': (255, 140, 40),
        'led_red': (255, 60, 60),
        # 리벳/볼트
        'rivet': (90, 95, 105),
        'rivet_highlight': (150, 155, 165),
        # 그루브/홈
        'groove': (30, 32, 40),
    }

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 게임 영역 위치 (중앙)
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 액자 테두리 두께
        self.frame_thickness = min(45, self.game_x - 5) if self.game_x > 10 else 0

        # 애니메이션 상태
        self.time = 0.0
        self.spawn_duration = 1.0
        self.is_spawning = True
        self.spawn_progress = 0.0

        # 모서리/볼트/패널 장식
        self.corner_brackets: List[dict] = []
        self.bolts: List[dict] = []
        self.led_strips: List[dict] = []

        # 스파크 파티클 (스폰 시)
        self.spark_particles: List[dict] = []

        self._init_mechanical_elements()

    def _init_mechanical_elements(self):
        """메카닉 요소 초기화"""
        if self.game_x < 20:
            return

        # 모서리 브라켓
        corners = [
            ('top_left', self.game_x, self.game_y, 0),
            ('top_right', self.game_x + self.game_width, self.game_y, 1),
            ('bottom_left', self.game_x, self.game_y + self.game_height, 2),
            ('bottom_right', self.game_x + self.game_width, self.game_y + self.game_height, 3),
        ]

        for name, x, y, idx in corners:
            self.corner_brackets.append({
                'name': name,
                'x': x,
                'y': y,
                'size': min(90, self.game_x - 5),
                'spawn_delay': 0.05 + idx * 0.1,
            })

        # 볼트 위치 (프레임 내부쪽에 배치 - LED와 겹치지 않게)
        bolt_spacing = 100
        bolt_inset = self.frame_thickness // 4  # 내부쪽으로 오프셋
        # 상단 볼트
        for i in range(int(self.game_width / bolt_spacing) + 1):
            bx = self.game_x + 30 + i * bolt_spacing
            if bx < self.game_x + self.game_width - 30:
                self.bolts.append({
                    'x': bx, 'y': self.game_y - bolt_inset - 3,
                    'spawn_delay': 0.3 + i * 0.02
                })
        # 하단 볼트
        for i in range(int(self.game_width / bolt_spacing) + 1):
            bx = self.game_x + 30 + i * bolt_spacing
            if bx < self.game_x + self.game_width - 30:
                self.bolts.append({
                    'x': bx, 'y': self.game_y + self.game_height + bolt_inset + 3,
                    'spawn_delay': 0.3 + i * 0.02
                })

        # LED 스트립 (프레임 외곽쪽에 배치)
        led_offset = self.frame_thickness - 8  # 외곽쪽
        self.led_strips.append({
            'side': 'top',
            'x1': self.game_x + 80,
            'x2': self.game_x + self.game_width - 80,
            'y': self.game_y - led_offset,
            'spawn_delay': 0.5,
        })
        self.led_strips.append({
            'side': 'bottom',
            'x1': self.game_x + 80,
            'x2': self.game_x + self.game_width - 80,
            'y': self.game_y + self.game_height + led_offset,
            'spawn_delay': 0.55,
        })

    def reset_animation(self):
        """애니메이션 리셋"""
        self.time = 0.0
        self.is_spawning = True
        self.spawn_progress = 0.0
        self.spark_particles.clear()

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt

        if self.is_spawning:
            self.spawn_progress = min(1.0, self.time / self.spawn_duration)
            if self.spawn_progress >= 1.0:
                self.is_spawning = False

            # 스폰 중 스파크 생성
            if self.spawn_progress < 0.8 and self.game_x > 20:
                self._spawn_sparks()

        # 스파크 업데이트
        for p in self.spark_particles[:]:
            p['life'] -= dt
            p['x'] += p['vx'] * dt * 60
            p['y'] += p['vy'] * dt * 60
            p['vy'] += 0.15 * dt * 60  # 약한 중력
            p['alpha'] = max(0, p['alpha'] - dt * 300)

            if p['life'] <= 0 or p['alpha'] <= 0:
                self.spark_particles.remove(p)

    def _spawn_sparks(self):
        """용접 스파크 생성"""
        if len(self.spark_particles) > 40:
            return

        # 모서리 근처에서 스파크
        for corner in self.corner_brackets:
            if random.random() > 0.15:
                continue

            self.spark_particles.append({
                'x': corner['x'] + random.uniform(-20, 20),
                'y': corner['y'] + random.uniform(-20, 20),
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-2, 1),
                'size': random.uniform(1, 2.5),
                'life': random.uniform(0.2, 0.4),
                'alpha': 255,
                'color': random.choice([
                    self.COLORS['led_orange'],
                    self.COLORS['chrome_bright'],
                    (255, 200, 100),
                ]),
            })

    def _ease_out_back(self, t: float) -> float:
        """백 이징"""
        c1 = 1.70158
        c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)

    def _get_spawn_scale(self, delay: float) -> float:
        """스폰 스케일"""
        adjusted_time = max(0, self.time - delay)
        adjusted_progress = min(1.0, adjusted_time / (self.spawn_duration * 0.5))
        return self._ease_out_back(adjusted_progress)

    def draw(self, surface: pygame.Surface):
        """액자 렌더링"""
        if self.game_x < 10:
            return

        if self.spawn_progress < 0.01:
            return

        # 1. 메인 메탈 프레임
        self._draw_metal_frame(surface)

        # 2. 모서리 브라켓
        self._draw_corner_brackets(surface)

        # 3. 볼트
        self._draw_bolts(surface)

        # 4. LED 스트립
        self._draw_led_strips(surface)

        # 5. 스파크 파티클
        self._draw_sparks(surface)

    def _draw_metal_frame(self, surface: pygame.Surface):
        """메탈 프레임 그리기"""
        scale = self._ease_out_back(min(1.0, self.spawn_progress * 1.1))
        if scale < 0.1:
            return

        thickness = max(5, int(self.frame_thickness * scale))

        # === 외부 그림자/베벨 ===
        shadow_offset = 3
        shadow_rect = pygame.Rect(
            self.game_x - thickness - shadow_offset,
            self.game_y - thickness - shadow_offset,
            self.game_width + (thickness + shadow_offset) * 2,
            self.game_height + (thickness + shadow_offset) * 2
        )
        pygame.draw.rect(surface, self.COLORS['metal_shadow'], shadow_rect, 4)

        # === 메인 메탈 베이스 - 베벨 효과 ===
        for layer in range(thickness, 0, -1):
            ratio = layer / thickness

            if ratio > 0.8:
                # 외곽 - 가장 어두운 메탈
                color = self.COLORS['metal_shadow']
            elif ratio > 0.6:
                # 베벨 다운
                t = (ratio - 0.6) / 0.2
                color = self._lerp_color(self.COLORS['metal_dark'],
                                        self.COLORS['metal_shadow'], t)
            elif ratio > 0.4:
                # 메인 메탈 면
                color = self.COLORS['metal']
            elif ratio > 0.2:
                # 베벨 업
                t = (ratio - 0.2) / 0.2
                color = self._lerp_color(self.COLORS['metal_light'],
                                        self.COLORS['metal'], t)
            else:
                # 내부 하이라이트
                t = ratio / 0.2
                color = self._lerp_color(self.COLORS['chrome'],
                                        self.COLORS['metal_light'], t)

            frame_rect = pygame.Rect(
                self.game_x - layer,
                self.game_y - layer,
                self.game_width + layer * 2,
                self.game_height + layer * 2
            )
            pygame.draw.rect(surface, color, frame_rect, 1)

        # === 내부 그루브 라인 (제거됨) ===
        # groove_offset = 4
        # groove_rect = pygame.Rect(
        #     self.game_x - groove_offset,
        #     self.game_y - groove_offset,
        #     self.game_width + groove_offset * 2,
        #     self.game_height + groove_offset * 2
        # )
        # pygame.draw.rect(surface, self.COLORS['groove'], groove_rect, 2)

        # === 내부 크롬 엣지 (제거됨) ===
        # inner_rect = pygame.Rect(
        #     self.game_x - 1,
        #     self.game_y - 1,
        #     self.game_width + 2,
        #     self.game_height + 2
        # )
        # pygame.draw.rect(surface, self.COLORS['chrome'], inner_rect, 1)

        # === 패널 라인 (수평 분할선) ===
        panel_y_top = self.game_y - thickness // 2
        panel_y_bottom = self.game_y + self.game_height + thickness // 2

        # 상단 패널 라인
        pygame.draw.line(surface, self.COLORS['groove'],
                        (self.game_x - thickness + 10, panel_y_top),
                        (self.game_x + self.game_width + thickness - 10, panel_y_top), 1)
        pygame.draw.line(surface, self.COLORS['metal_light'],
                        (self.game_x - thickness + 10, panel_y_top + 1),
                        (self.game_x + self.game_width + thickness - 10, panel_y_top + 1), 1)

        # 하단 패널 라인
        pygame.draw.line(surface, self.COLORS['groove'],
                        (self.game_x - thickness + 10, panel_y_bottom),
                        (self.game_x + self.game_width + thickness - 10, panel_y_bottom), 1)
        pygame.draw.line(surface, self.COLORS['metal_light'],
                        (self.game_x - thickness + 10, panel_y_bottom + 1),
                        (self.game_x + self.game_width + thickness - 10, panel_y_bottom + 1), 1)

    def _draw_corner_brackets(self, surface: pygame.Surface):
        """모서리 브라켓"""
        for bracket in self.corner_brackets:
            scale = self._get_spawn_scale(bracket['spawn_delay'])
            if scale < 0.1:
                continue

            x, y = bracket['x'], bracket['y']
            size = int(bracket['size'] * scale)
            name = bracket['name']

            flip_x = 1 if 'right' in name else -1
            flip_y = 1 if 'bottom' in name else -1

            self._draw_bracket(surface, x, y, size, flip_x, flip_y)

    def _draw_bracket(self, surface: pygame.Surface, cx: int, cy: int,
                      size: int, flip_x: int, flip_y: int):
        """개별 브라켓 그리기"""
        # L자형 브라켓 두께
        bracket_thickness = max(8, size // 6)
        arm_length = int(size * 0.65)

        # 오프셋
        offset = self.frame_thickness // 2
        start_x = cx - offset * flip_x
        start_y = cy - offset * flip_y

        # === L자형 메탈 브라켓 ===

        # 수평 암 (메인 바디)
        h_rect = pygame.Rect(
            min(start_x, start_x + arm_length * flip_x) - (bracket_thickness // 2 if flip_x < 0 else 0),
            start_y - bracket_thickness // 2,
            abs(arm_length) + bracket_thickness // 2,
            bracket_thickness
        )

        # 수직 암
        v_rect = pygame.Rect(
            start_x - bracket_thickness // 2,
            min(start_y, start_y + arm_length * flip_y) - (bracket_thickness // 2 if flip_y < 0 else 0),
            bracket_thickness,
            abs(arm_length) + bracket_thickness // 2
        )

        # 브라켓 그리기 - 베벨 효과
        for rect in [h_rect, v_rect]:
            # 어두운 베이스
            pygame.draw.rect(surface, self.COLORS['metal_dark'], rect)

            # 상단/좌측 하이라이트
            pygame.draw.line(surface, self.COLORS['metal_light'],
                           rect.topleft, rect.topright, 1)
            pygame.draw.line(surface, self.COLORS['metal_light'],
                           rect.topleft, rect.bottomleft, 1)

            # 하단/우측 그림자
            pygame.draw.line(surface, self.COLORS['metal_shadow'],
                           rect.bottomleft, rect.bottomright, 1)
            pygame.draw.line(surface, self.COLORS['metal_shadow'],
                           rect.topright, rect.bottomright, 1)

        # === 코너 보강판 (삼각형) ===
        tri_size = bracket_thickness * 1.5
        tri_points = [
            (start_x, start_y),
            (start_x + tri_size * flip_x, start_y),
            (start_x, start_y + tri_size * flip_y),
        ]
        pygame.draw.polygon(surface, self.COLORS['metal'],
                          [(int(p[0]), int(p[1])) for p in tri_points])
        pygame.draw.polygon(surface, self.COLORS['metal_light'],
                          [(int(p[0]), int(p[1])) for p in tri_points], 1)

        # === 볼트 (브라켓 끝) ===
        bolt_positions = [
            (start_x + arm_length * 0.7 * flip_x, start_y),
            (start_x, start_y + arm_length * 0.7 * flip_y),
        ]

        for bx, by in bolt_positions:
            self._draw_single_bolt(surface, int(bx), int(by), 4)

        # === LED 인디케이터 (코너) ===
        led_x = start_x + bracket_thickness * 0.8 * flip_x
        led_y = start_y + bracket_thickness * 0.8 * flip_y

        pulse = 0.7 + 0.3 * math.sin(self.time * 4)
        led_color = self._lerp_color(self.COLORS['led_cyan_dim'],
                                    self.COLORS['led_cyan'], pulse)

        # LED 글로우
        glow_size = 4
        glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*led_color, int(80 * pulse)),
                          (glow_size * 2, glow_size * 2), glow_size * 2)
        pygame.draw.circle(glow_surf, (*self.COLORS['led_cyan'], int(200 * pulse)),
                          (glow_size * 2, glow_size * 2), glow_size)
        pygame.draw.circle(glow_surf, self.COLORS['chrome_bright'],
                          (glow_size * 2, glow_size * 2), 2)
        surface.blit(glow_surf, (int(led_x) - glow_size * 2, int(led_y) - glow_size * 2))

    def _draw_bolts(self, surface: pygame.Surface):
        """볼트 그리기"""
        for bolt in self.bolts:
            scale = self._get_spawn_scale(bolt['spawn_delay'])
            if scale < 0.3:
                continue

            self._draw_single_bolt(surface, int(bolt['x']), int(bolt['y']), 5)

    def _draw_single_bolt(self, surface: pygame.Surface, x: int, y: int, radius: int):
        """단일 볼트"""
        # 볼트 홈
        pygame.draw.circle(surface, self.COLORS['groove'], (x, y), radius + 1)

        # 볼트 헤드
        pygame.draw.circle(surface, self.COLORS['rivet'], (x, y), radius)

        # 하이라이트
        pygame.draw.circle(surface, self.COLORS['rivet_highlight'],
                          (x - 1, y - 1), radius - 2)

        # 십자 홈
        pygame.draw.line(surface, self.COLORS['groove'],
                        (x - radius + 2, y), (x + radius - 2, y), 1)
        pygame.draw.line(surface, self.COLORS['groove'],
                        (x, y - radius + 2), (x, y + radius - 2), 1)

    def _draw_led_strips(self, surface: pygame.Surface):
        """LED 스트립"""
        for strip in self.led_strips:
            scale = self._get_spawn_scale(strip['spawn_delay'])
            if scale < 0.5:
                continue

            x1, x2, y = strip['x1'], strip['x2'], strip['y']
            width = int((x2 - x1) * scale)
            center_x = (x1 + x2) // 2

            # LED 스트립 배경 (어두운 채널)
            pygame.draw.line(surface, self.COLORS['groove'],
                           (center_x - width // 2, y),
                           (center_x + width // 2, y), 4)

            # LED 글로우
            pulse = 0.6 + 0.4 * math.sin(self.time * 3)
            led_color = self._lerp_color(self.COLORS['led_cyan_dim'],
                                        self.COLORS['led_cyan'], pulse)

            # 글로우 라인
            glow_surf = pygame.Surface((width, 12), pygame.SRCALPHA)
            pygame.draw.line(glow_surf, (*led_color, int(60 * pulse)),
                           (0, 6), (width, 6), 8)
            pygame.draw.line(glow_surf, (*self.COLORS['led_cyan'], int(180 * pulse)),
                           (0, 6), (width, 6), 3)
            pygame.draw.line(glow_surf, self.COLORS['chrome_bright'],
                           (0, 6), (width, 6), 1)
            surface.blit(glow_surf, (center_x - width // 2, y - 6))

            # LED 세그먼트 표시
            segment_spacing = 20
            num_segments = width // segment_spacing
            for i in range(num_segments):
                seg_x = center_x - width // 2 + i * segment_spacing + segment_spacing // 2
                seg_pulse = 0.5 + 0.5 * math.sin(self.time * 5 + i * 0.5)
                pygame.draw.circle(surface, self.COLORS['chrome_bright'],
                                 (seg_x, y), 2 if seg_pulse > 0.7 else 1)

    def _draw_sparks(self, surface: pygame.Surface):
        """스파크 파티클"""
        for p in self.spark_particles:
            if p['alpha'] <= 0:
                continue

            size = max(1, int(p['size']))
            alpha = int(p['alpha'])

            # 스파크 글로우
            glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*p['color'], alpha // 3),
                             (size * 2, size * 2), size * 2)
            pygame.draw.circle(glow_surf, (*p['color'], alpha),
                             (size * 2, size * 2), size)
            surface.blit(glow_surf, (int(p['x']) - size * 2, int(p['y']) - size * 2))

    def _lerp_color(self, c1: tuple, c2: tuple, t: float) -> tuple:
        """색상 보간"""
        return (
            int(c1[0] + (c2[0] - c1[0]) * t),
            int(c1[1] + (c2[1] - c1[1]) * t),
            int(c1[2] + (c2[2] - c1[2]) * t),
        )


# 싱글톤 인스턴스
_baroque_frame_instance: Optional[BaroqueFrame] = None


def init_baroque_background(screen_width: int, screen_height: int,
                            game_width: int, game_height: int) -> BaroqueFrame:
    """메카닉 액자 초기화"""
    global _baroque_frame_instance
    _baroque_frame_instance = BaroqueFrame(screen_width, screen_height, game_width, game_height)
    return _baroque_frame_instance


def get_baroque_background() -> Optional[BaroqueFrame]:
    """메카닉 액자 인스턴스 반환"""
    return _baroque_frame_instance
