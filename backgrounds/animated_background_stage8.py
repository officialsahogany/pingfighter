"""Stage 8 전용 애니메이션 배경 - 닌자 저택.

창문 빛 효과, 등불 깜빡임, 스타디움 펄스 애니메이션.
"""

from __future__ import annotations

import math
import random
from typing import List, Tuple

import pygame

Color = Tuple[int, int, int]


class AnimatedBackgroundStage8:
    """Stage 8 배경 위에 얹는 애니메이션 오버레이."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.time = 0.0

        # 등불 위치 (배경과 동일)
        self.lantern_positions: List[Tuple[int, int]] = [
            (30, 200),
            (30, height - 200),
            (width - 30, 200),
            (width - 30, height - 200),
        ]

        # 등불 상태
        self.lantern_states: List[dict] = []
        for _ in range(len(self.lantern_positions)):
            self.lantern_states.append({
                "phase": random.uniform(0, math.tau),
                "intensity": random.uniform(0.7, 1.0),
                "flicker_speed": random.uniform(2.0, 4.0),
            })

        # 창문 위치 (왼쪽, 오른쪽)
        self.window_positions_left = [
            (5, 80, 50, 120),
            (5, 280, 50, 120),
            (5, 480, 50, 120),
        ]
        self.window_positions_right = [
            (width - 55, 80, 50, 120),
            (width - 55, 280, 50, 120),
            (width - 55, 480, 50, 120),
        ]

        # 창문 빛 상태
        self.window_states: List[dict] = []
        for _ in range(6):
            self.window_states.append({
                "phase": random.uniform(0, math.tau),
                "intensity": random.uniform(0.3, 0.6),
                "speed": random.uniform(0.5, 1.5),
            })

        # 스타디움 펄스
        self.stadium_pulse_phase = 0.0
        self.stadium_line_y = height // 2
        self.stadium_circle_radius = 80

        # 먼지 입자 (적게)
        self.dust_particles: List[dict] = []
        for _ in range(15):
            self.dust_particles.append({
                "x": random.uniform(70, width - 70),
                "y": random.uniform(60, height - 60),
                "speed_x": random.uniform(-5.0, 5.0),
                "speed_y": random.uniform(-3.0, 3.0),
                "phase": random.uniform(0, math.tau),
                "radius": random.uniform(1.0, 2.0),
                "alpha": random.randint(20, 40),
            })

    def update(self, elapsed_ms: int | float | None = None) -> None:
        """프레임마다 호출."""
        if elapsed_ms is None:
            elapsed_ms = 16
        dt = (elapsed_ms or 0) / 1000.0
        self.time += dt

        # 등불 업데이트
        for state in self.lantern_states:
            state["intensity"] = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(
                self.time * state["flicker_speed"] + state["phase"]))
            if random.random() < 0.008:
                state["intensity"] *= random.uniform(0.4, 0.7)

        # 창문 빛 업데이트
        for state in self.window_states:
            state["intensity"] = 0.3 + 0.2 * math.sin(
                self.time * state["speed"] + state["phase"])

        # 스타디움 펄스
        self.stadium_pulse_phase = self.time * 1.0

        # 먼지 입자 업데이트
        for dust in self.dust_particles:
            dust["x"] += dust["speed_x"] * dt
            dust["y"] += dust["speed_y"] * dt + math.sin(self.time * 0.5 + dust["phase"]) * 0.2

            if dust["x"] < 70:
                dust["x"] = self.width - 70
            elif dust["x"] > self.width - 70:
                dust["x"] = 70
            if dust["y"] < 60:
                dust["y"] = self.height - 60
            elif dust["y"] > self.height - 60:
                dust["y"] = 60

    def draw(self, surface: pygame.Surface, *, offset: Tuple[int, int] = (0, 0)) -> None:
        """애니메이션 레이어를 그린다."""
        ox, oy = offset
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # 1. 창문 빛 효과
        self._draw_window_glow(overlay)

        # 2. 등불 빛 효과
        self._draw_lantern_glow(overlay)

        # 3. 먼지 입자
        self._draw_dust(overlay)

        # 4. 스타디움 펄스
        self._draw_stadium_pulse(overlay)

        surface.blit(overlay, (ox, oy))

    def _draw_window_glow(self, overlay: pygame.Surface) -> None:
        """창문에서 나오는 은은한 빛."""
        all_windows = self.window_positions_left + self.window_positions_right

        for i, (wx, wy, ww, wh) in enumerate(all_windows):
            state = self.window_states[i]
            intensity = state["intensity"]

            # 창문 내부 빛
            glow_alpha = int(25 * intensity)
            if glow_alpha > 0:
                # 창문 영역에 은은한 빛
                glow_surf = pygame.Surface((ww, wh), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (60, 50, 40, glow_alpha), (0, 0, ww, wh))
                overlay.blit(glow_surf, (wx + 4, wy + 4))

                # 창문 주변 빛 번짐
                for r in range(3):
                    spread_alpha = max(0, glow_alpha - r * 8)
                    pygame.draw.rect(overlay, (50, 40, 30, spread_alpha),
                                   (wx - r * 3, wy - r * 3, ww + r * 6, wh + r * 6), 1)

    def _draw_lantern_glow(self, overlay: pygame.Surface) -> None:
        """등불 빛 효과."""
        for i, (lx, ly) in enumerate(self.lantern_positions):
            state = self.lantern_states[i]
            intensity = state["intensity"]

            # 글로우
            for layer in range(3):
                radius = int(18 + layer * 10)
                alpha = int(18 * intensity - layer * 5)
                if alpha > 0:
                    glow_color = (
                        int(100 * intensity),
                        int(55 * intensity),
                        int(20 * intensity),
                        alpha
                    )
                    pygame.draw.circle(overlay, glow_color, (lx, ly), radius)

    def _draw_dust(self, overlay: pygame.Surface) -> None:
        """떠다니는 먼지 입자."""
        for dust in self.dust_particles:
            wobble = 0.3 * math.sin(self.time * 2 + dust["phase"])
            radius = max(1, int(dust["radius"] + wobble))
            color = (70, 65, 55, dust["alpha"])
            pygame.draw.circle(overlay, color, (int(dust["x"]), int(dust["y"])), radius)

    def _draw_stadium_pulse(self, overlay: pygame.Surface) -> None:
        """스타디움 펄스 효과."""
        pulse = 0.5 + 0.5 * math.sin(self.stadium_pulse_phase)
        center_x = self.width // 2
        center_y = self.stadium_line_y

        glow_alpha = int(15 + 10 * pulse)
        glow_color = (130, 50, 50)

        # 중앙 라인 글로우
        for i in range(2):
            line_alpha = max(0, glow_alpha - i * 6)
            pygame.draw.line(overlay, (*glow_color, line_alpha),
                           (60, center_y - i), (self.width - 60, center_y - i), 1)
            pygame.draw.line(overlay, (*glow_color, line_alpha),
                           (60, center_y + i), (self.width - 60, center_y + i), 1)

        # 중앙 서클 글로우
        for i in range(3):
            circle_alpha = max(0, glow_alpha - i * 4)
            pygame.draw.circle(overlay, (*glow_color, circle_alpha),
                             (center_x, center_y), self.stadium_circle_radius + i * 2, 1)
