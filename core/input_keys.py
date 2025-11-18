"""
입력 키 매핑 유틸리티

한/영 키보드 및 IME 환경에서 A/D 기반 좌우 이동을
항상 안정적으로 인식하기 위한 공용 헬퍼를 제공한다.
"""

from __future__ import annotations

import pygame
from typing import Sequence

# 이동 관련 키 세트
MOVE_LEFT_KEYS = {
    pygame.K_LEFT,
    pygame.K_a,
    0x61,
    0x6E,
}

MOVE_RIGHT_KEYS = {
    pygame.K_RIGHT,
    pygame.K_d,
    0x64,
    0x6F,
}


def is_move_left_key(key_code: int) -> bool:
    """왼쪽 이동 키인지 여부 (KEYDOWN/KEYUP용)"""
    return key_code in MOVE_LEFT_KEYS


def is_move_right_key(key_code: int) -> bool:
    """오른쪽 이동 키인지 여부 (KEYDOWN/KEYUP용)"""
    return key_code in MOVE_RIGHT_KEYS


def is_move_left_pressed(keys: Sequence[bool]) -> bool:
    """현재 프레임에서 왼쪽 이동 키가 눌려 있는지 확인"""
    for key_code in MOVE_LEFT_KEYS:
        try:
            if keys[key_code]:
                return True
        except (IndexError, TypeError):
            continue
    return False


def is_move_right_pressed(keys: Sequence[bool]) -> bool:
    """현재 프레임에서 오른쪽 이동 키가 눌려 있는지 확인"""
    for key_code in MOVE_RIGHT_KEYS:
        try:
            if keys[key_code]:
                return True
        except (IndexError, TypeError):
            continue
    return False

