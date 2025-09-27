"""별탐지기 - 스타포인트 추가 스폰 패시브"""

from __future__ import annotations

import random
from typing import Tuple

# 내부 상태
_active = False
_bonus_chance = 0.25
_extra_spawn_count = 1  # 추가로 스폰할 별 개수 (기본 1 → 총 2배)
_last_triggered: Tuple[float, float] | None = None


def activate_star_detector() -> None:
    """별탐지기 효과를 활성화한다."""
    global _active
    _active = True


def deactivate_star_detector() -> None:
    """별탐지기 효과를 비활성화하고 상태를 초기화한다."""
    global _active, _last_triggered
    _active = False
    _last_triggered = None


def is_star_detector_active() -> bool:
    """현재 별탐지기가 활성화되어 있는지 반환한다."""
    return _active


def roll_star_bonus() -> int:
    """별 드랍 시 추가로 스폰할 별 개수를 결정한다.

    Returns:
        추가로 스폰할 별 개수 (0 또는 양수)
    """
    global _last_triggered
    if not _active:
        return 0

    if random.random() < _bonus_chance:
        return _extra_spawn_count
    return 0


def record_trigger(position: Tuple[float, float]) -> None:
    """최근 발동 위치를 기록한다. (디버그 용도)"""
    global _last_triggered
    _last_triggered = position


def get_last_trigger() -> Tuple[float, float] | None:
    """최근 발동 위치를 반환한다."""
    return _last_triggered
