"""Stage 7 전용 애니메이션 배경.

중세 요새 내부 느낌을 유지하면서 은은한 조명과 조그마한 빛 입자를 움직여
정적인 배경 위에 생동감을 추가한다.
"""

from __future__ import annotations

import math
import random
from typing import List, Tuple

import pygame

Color = Tuple[int, int, int]


class AnimatedBackgroundStage7:
    """Stage 7 배경 위에 얹는 경량 애니메이션 오버레이."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.time = 0.0

        # 토치 중심 좌표 (정적인 배경과 동일 위치)
        self.torch_positions: List[Tuple[int, int]] = [
            (96, 176),
            (width - 96, 176),
            (96, height - 220),
            (width - 96, height - 220),
        ]

        # 내부 잔광 효과용 파티클
        self.light_motes: List[dict] = []
        for _ in range(12):
            self.light_motes.append(
                {
                    "x": random.uniform(140, width - 140),
                    "y": random.uniform(height / 2 - 90, height / 2 + 110),
                    "speed": random.uniform(12.0, 26.0),  # px/sec
                    "phase": random.uniform(0, math.tau),
                    "radius": random.uniform(2.0, 4.0),
                }
            )

        # 이동하는 라이트 밴드 설정
        self.band_width = 200
        self.band_height = 180
        self.band_top = int(height / 2 - self.band_height / 2)

    def update(self, elapsed_ms: int | float | None = None) -> None:
        """프레임마다 호출. elapsed_ms는 pygame clock 값(ms)"""

        if elapsed_ms is None:
            elapsed_ms = 16
        dt = (elapsed_ms or 0) / 1000.0
        self.time += dt

        for mote in self.light_motes:
            mote["x"] += mote["speed"] * dt
            mote["y"] += math.sin(self.time * 2.0 + mote["phase"]) * 0.5
            if mote["x"] > self.width + 40:
                mote["x"] = -40
                mote["y"] = random.uniform(self.height / 2 - 90, self.height / 2 + 110)
                mote["phase"] = random.uniform(0, math.tau)

    def draw(self, surface: pygame.Surface, *, offset: Tuple[int, int] = (0, 0)) -> None:
        """애니메이션 레이어를 그린다.

        Args:
            surface: 대상 Surface (보통 SCREEN 또는 사본)
            offset: 전체 배경이 이동할 때의 오프셋 (스크린 흔들림 등)
        """

        ox, oy = offset
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        self._draw_torch_glow(overlay)
        self._draw_light_band(overlay)
        self._draw_motes(overlay)

        surface.blit(overlay, (ox, oy))

    # ------------------------------------------------------------------
    # 내부 헬퍼
    # ------------------------------------------------------------------
    def _draw_torch_glow(self, overlay: pygame.Surface) -> None:
        for index, (x, y) in enumerate(self.torch_positions):
            wobble = 0.4 + 0.3 * math.sin(self.time * 6.0 + index * 1.7)
            radius = 56 + 4 * math.sin(self.time * 4.3 + index)
            alpha = int(90 + 70 * wobble)
            color = (255, 208, 120, alpha)
            pygame.draw.circle(overlay, color, (x, y), int(radius))

            inner_alpha = int(160 + 40 * wobble)
            pygame.draw.circle(overlay, (255, 230, 180, inner_alpha), (x, y - 6), 22)

    def _draw_light_band(self, overlay: pygame.Surface) -> None:
        band_surface = pygame.Surface((self.band_width, self.band_height), pygame.SRCALPHA)
        half = self.band_width / 2
        for x in range(self.band_width):
            intensity = max(0.0, 1.0 - abs(x - half) / half)
            alpha = int(70 * (intensity ** 1.8))
            color = (120, 186, 255, alpha)
            pygame.draw.line(band_surface, color, (x, 0), (x, self.band_height))

        sweep = (self.time * 120) % (self.width + self.band_width) - self.band_width
        overlay.blit(
            band_surface,
            (int(sweep), self.band_top),
            special_flags=pygame.BLEND_PREMULTIPLIED,
        )

    def _draw_motes(self, overlay: pygame.Surface) -> None:
        for mote in self.light_motes:
            wobble = math.sin(self.time * 3.0 + mote["phase"])
            radius = mote["radius"] + wobble * 0.4
            alpha = int(80 + 40 * wobble)
            pygame.draw.circle(
                overlay,
                (170, 220, 255, alpha),
                (int(mote["x"]), int(mote["y"])),
                max(1, int(radius)),
            )
