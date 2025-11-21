"""Stage 8 전용 애니메이션 배경 - 미니멀 버전.

깔끔한 배경 위에 은은한 등불 깜빡임과 스타디움 펄스만 추가.
"""

from __future__ import annotations

import math
import random
from typing import List, Tuple

import pygame

Color = Tuple[int, int, int]


class AnimatedBackgroundStage8:
    """Stage 8 배경 위에 얹는 경량 애니메이션 오버레이 - 미니멀 버전."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.time = 0.0

        # 등불 위치 (정적인 배경과 동일 위치)
        self.lantern_positions: List[Tuple[int, int]] = [
            (35, 195),              # 왼쪽 상단
            (35, height - 205),     # 왼쪽 하단
            (width - 35, 195),      # 오른쪽 상단
            (width - 35, height - 205),  # 오른쪽 하단
        ]

        # 등불 상태 (개별 깜빡임 위상)
        self.lantern_states: List[dict] = []
        for i in range(len(self.lantern_positions)):
            self.lantern_states.append({
                "phase": random.uniform(0, math.tau),
                "intensity": random.uniform(0.7, 1.0),
                "flicker_speed": random.uniform(2.0, 4.0),
            })

        # 스타디움 라인 펄스 효과
        self.stadium_pulse_phase = 0.0
        self.stadium_line_y = height // 2
        self.stadium_circle_radius = 80
        self.stadium_color = (100, 40, 40)
        self.stadium_glow_color = (140, 50, 50)

    def update(self, elapsed_ms: int | float | None = None) -> None:
        """프레임마다 호출. elapsed_ms는 pygame clock 값(ms)"""
        if elapsed_ms is None:
            elapsed_ms = 16
        dt = (elapsed_ms or 0) / 1000.0
        self.time += dt

        # 등불 상태 업데이트
        for state in self.lantern_states:
            state["intensity"] = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(
                self.time * state["flicker_speed"] + state["phase"]))
            # 가끔 깜빡임 (랜덤 플리커)
            if random.random() < 0.005:
                state["intensity"] *= random.uniform(0.5, 0.8)

        # 스타디움 펄스 업데이트
        self.stadium_pulse_phase = self.time * 1.2

    def draw(self, surface: pygame.Surface, *, offset: Tuple[int, int] = (0, 0)) -> None:
        """애니메이션 레이어를 그린다."""
        ox, oy = offset
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # 1. 등불 빛 효과
        self._draw_lantern_glow(overlay)

        # 2. 스타디움 라인 펄스 효과
        self._draw_stadium_pulse(overlay)

        surface.blit(overlay, (ox, oy))

    def _draw_lantern_glow(self, overlay: pygame.Surface) -> None:
        """등불 빛 효과 (깜빡이는 따뜻한 빛)"""
        for i, (lx, ly) in enumerate(self.lantern_positions):
            state = self.lantern_states[i]
            intensity = state["intensity"]

            # 은은한 글로우 (2겹만)
            base_color = (100, 50, 20)
            for layer in range(2):
                radius = int(20 + layer * 12)
                alpha = int(15 * intensity - layer * 5)
                if alpha > 0:
                    glow_color = (
                        min(255, int(base_color[0] * intensity)),
                        min(255, int(base_color[1] * intensity)),
                        min(255, int(base_color[2] * intensity)),
                        alpha
                    )
                    pygame.draw.circle(overlay, glow_color, (lx, ly), radius)

    def _draw_stadium_pulse(self, overlay: pygame.Surface) -> None:
        """스타디움 라인 펄스 효과"""
        pulse = 0.5 + 0.5 * math.sin(self.stadium_pulse_phase)
        center_x = self.width // 2
        center_y = self.stadium_line_y

        # 글로우 효과 (맥동)
        glow_alpha = int(20 + 15 * pulse)

        # 중앙 라인 글로우
        for i in range(3):
            line_alpha = max(0, glow_alpha - i * 5)
            pygame.draw.line(
                overlay,
                (*self.stadium_glow_color, line_alpha),
                (0, center_y - i), (self.width, center_y - i),
                1
            )
            pygame.draw.line(
                overlay,
                (*self.stadium_glow_color, line_alpha),
                (0, center_y + i), (self.width, center_y + i),
                1
            )

        # 중앙 서클 글로우
        for i in range(4):
            circle_alpha = max(0, glow_alpha - i * 4)
            pygame.draw.circle(
                overlay,
                (*self.stadium_glow_color, circle_alpha),
                (center_x, center_y),
                self.stadium_circle_radius + i * 2,
                1
            )
