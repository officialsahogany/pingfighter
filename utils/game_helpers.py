"""PingFighter 전역에서 사용하는 공용 헬퍼 함수 모음."""

from __future__ import annotations

import math
from typing import Iterable, Tuple

StageColor = Tuple[int, int, int]
Color = Tuple[int, int, int]
ColorWithAlpha = Tuple[int, int, int, int]

__all__ = [
    "get_stage_color",
    "fade_color",
    "blend_colors",
    "get_center_pos",
    "calculate_distance",
]


def get_stage_color(stage: int) -> StageColor:
    stage_colors = {
        1: (0, 150, 100),
        2: (0, 100, 200),
        3: (255, 0, 128),
        4: (255, 215, 0),
        5: (255, 100, 0),
        6: (128, 0, 255),
    }
    return stage_colors.get(stage, (255, 255, 255))


def fade_color(color: Iterable[int], alpha: int) -> ColorWithAlpha:
    base = tuple(color)
    if len(base) == 3:
        return (*base, alpha)
    return base  # 이미 알파가 포함되어 있음


def blend_colors(color1: Iterable[int], color2: Iterable[int], ratio: float) -> Color:
    r1, g1, b1 = color1[:3]
    r2, g2, b2 = color2[:3]
    r = int(r1 * (1 - ratio) + r2 * ratio)
    g = int(g1 * (1 - ratio) + g2 * ratio)
    b = int(b1 * (1 - ratio) + b2 * ratio)
    return (r, g, b)


def get_center_pos(rect) -> Tuple[int, int]:
    return rect.centerx, rect.centery


def calculate_distance(pos1: Iterable[float], pos2: Iterable[float]) -> float:
    x1, y1 = pos1
    x2, y2 = pos2
    return math.hypot(x1 - x2, y1 - y2)
