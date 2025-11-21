"""
입력 키 매핑 유틸리티

한/영 키보드 및 IME 환경에서 A/D 기반 좌우 이동을
항상 안정적으로 인식하기 위한 공용 헬퍼를 제공한다.
디버깅이 필요할 때는 환경변수 `PINGF_INPUT_DEBUG=1`을 설정하면
키 판정 상태가 0.5초 간격으로 콘솔에 출력된다.
"""

from __future__ import annotations

import os
import pygame
from typing import Sequence, Iterable, Optional


def _get_scancode(name: str) -> Optional[int]:
    """pygame SCANCODE_* 상수를 안전하게 조회한다."""
    return getattr(pygame, f"SCANCODE_{name}", None)


def _key_code_safe(symbol: str, fallback: int) -> int:
    """pygame.key.key_code 호출이 실패해도 안전한 키코드 조회."""
    try:
        return pygame.key.key_code(symbol)
    except Exception:
        return fallback


def _iter_present(values: Iterable[Optional[int] | int]) -> set[int]:
    return {v for v in values if v is not None}


# SDL 기본 스캔코드(플랫폼 공통) – pygame 2.6.x는 SCANCODE_* 상수를 노출하지 않아 직접 지정
SCANCODE_LEFT_FALLBACK = 80
SCANCODE_RIGHT_FALLBACK = 79
SCANCODE_A_FALLBACK = 4
SCANCODE_D_FALLBACK = 7
SCANCODE_DOWN_FALLBACK = 81
SCANCODE_S_FALLBACK = 22
SCANCODE_UP_FALLBACK = 82
SCANCODE_W_FALLBACK = 26
# 두벌식/세벌식 한글 배열에서 A, D에 매핑되는 유니코드 키코드
HANGUL_A_KEYCODE = _key_code_safe("ㅁ", 0x3141)  # U+3141
HANGUL_D_KEYCODE = _key_code_safe("ㅇ", 0x3147)  # U+3147
HANGUL_S_KEYCODE = _key_code_safe("ㄴ", 0x3134)  # 두벌식 S 위치
HANGUL_S_CHO_KEYCODE = _key_code_safe("ᄂ", 0x1102)  # 초성 ㄴ
HANGUL_W_KEYCODE = _key_code_safe("ㅈ", 0x3148)  # U+3148
# 디버그 플래그
INPUT_DEBUG = os.environ.get("PINGF_INPUT_DEBUG", "").lower() in ("1", "true", "yes", "on")
_last_debug_ms = 0


def _safe_key_state(keys: Sequence[bool], idx: int) -> int:
    try:
        return int(keys[idx])
    except Exception:
        return -1  # 인덱스 오류 등

# 이동 관련 키 세트 (keycode 기반)
# - 0x6E/0x6F: 일부 IME 드라이버가 키코드를 치환해 보고하는 경우 대응
MOVE_LEFT_KEYS = {
    pygame.K_LEFT,
    pygame.K_a,
    0x61,  # ASCII 'a'
    0x6E,  # 보고된 IME 치환 키
    HANGUL_A_KEYCODE,  # 한글 모드(두벌식) A 물리키
}

MOVE_RIGHT_KEYS = {
    pygame.K_RIGHT,
    pygame.K_d,
    0x64,  # ASCII 'd'
    0x6F,  # 보고된 IME 치환 키
    HANGUL_D_KEYCODE,  # 한글 모드(두벌식) D 물리키
}
MOVE_DOWN_KEYS = {
    pygame.K_DOWN,
    pygame.K_s,
    0x73,  # ASCII 's'
    0x6D,  # 보고된 IME 치환 키(m)
    HANGUL_S_KEYCODE,  # 한글 모드(두벌식) S 물리키
    HANGUL_S_CHO_KEYCODE,  # 초성 보고 케이스
}
MOVE_UP_KEYS = {
    pygame.K_UP,
    pygame.K_w,
    0x77,  # ASCII 'w'
    0x6A,  # 보고된 IME 치환 키(j) 사례 대비
    HANGUL_W_KEYCODE,  # 한글 모드(두벌식) W 물리키
}

# 이동 관련 스캔코드 세트(물리 키 기준) - 레이아웃/IME 무관
MOVE_LEFT_SCANCODES = _iter_present(
    (
        _get_scancode("LEFT"),
        _get_scancode("A"),
        SCANCODE_LEFT_FALLBACK,
        SCANCODE_A_FALLBACK,
    )
)
MOVE_RIGHT_SCANCODES = _iter_present(
    (
        _get_scancode("RIGHT"),
        _get_scancode("D"),
        SCANCODE_RIGHT_FALLBACK,
        SCANCODE_D_FALLBACK,
    )
)
MOVE_DOWN_SCANCODES = _iter_present(
    (
        _get_scancode("DOWN"),
        _get_scancode("S"),
        SCANCODE_DOWN_FALLBACK,
        SCANCODE_S_FALLBACK,
    )
)
MOVE_UP_SCANCODES = _iter_present(
    (
        _get_scancode("UP"),
        _get_scancode("W"),
        SCANCODE_UP_FALLBACK,
        SCANCODE_W_FALLBACK,
    )
)

# 레이아웃/IME에 따라 keycode가 UNKNOWN으로 떨어질 때 unicode로만 전달되는 경우를 위한 보조 매핑
MOVE_LEFT_UNICODES = {"a", "A", "ㅁ"}  # ㅁ: 한글 두벌식에서 A 위치
MOVE_RIGHT_UNICODES = {"d", "D", "ㅇ"}  # ㅇ: 한글 두벌식에서 D 위치
MOVE_DOWN_UNICODES = {"s", "S", "ㄴ"}  # ㄴ: 한글 두벌식에서 S 위치
MOVE_UP_UNICODES = {"w", "W", "ㅈ"}  # ㅈ: 한글 두벌식에서 W 위치


def _is_pressed(keys: Sequence[bool], code: int) -> bool:
    """keys[code] 접근 시 발생할 수 있는 예외를 모두 흡수하고 bool 결과만 반환."""
    try:
        return bool(keys[code])
    except Exception:
        return False


def _any_move_left_pressed(keys: Sequence[bool]) -> bool:
    for key_code in MOVE_LEFT_KEYS:
        if _is_pressed(keys, key_code):
            return True
    for scancode in MOVE_LEFT_SCANCODES:
        if _is_pressed(keys, scancode):
            return True
    return False


def _any_move_right_pressed(keys: Sequence[bool]) -> bool:
    for key_code in MOVE_RIGHT_KEYS:
        if _is_pressed(keys, key_code):
            return True
    for scancode in MOVE_RIGHT_SCANCODES:
        if _is_pressed(keys, scancode):
            return True
    return False


def _any_move_down_pressed(keys: Sequence[bool]) -> bool:
    for key_code in MOVE_DOWN_KEYS:
        if _is_pressed(keys, key_code):
            return True
    for scancode in MOVE_DOWN_SCANCODES:
        if _is_pressed(keys, scancode):
            return True
    return False


def _any_move_up_pressed(keys: Sequence[bool]) -> bool:
    for key_code in MOVE_UP_KEYS:
        if _is_pressed(keys, key_code):
            return True
    for scancode in MOVE_UP_SCANCODES:
        if _is_pressed(keys, scancode):
            return True
    return False


def is_move_left_key(key_code: int, scancode: int | None = None) -> bool:
    """왼쪽 이동 키인지 여부 (KEYDOWN/KEYUP용, 스캔코드 보조 지원)"""
    if key_code in MOVE_LEFT_KEYS:
        return True
    if scancode is not None and scancode in MOVE_LEFT_SCANCODES:
        return True
    return False


def is_move_right_key(key_code: int, scancode: int | None = None) -> bool:
    """오른쪽 이동 키인지 여부 (KEYDOWN/KEYUP용, 스캔코드 보조 지원)"""
    if key_code in MOVE_RIGHT_KEYS:
        return True
    if scancode is not None and scancode in MOVE_RIGHT_SCANCODES:
        return True
    return False


def is_move_down_key(key_code: int, scancode: int | None = None) -> bool:
    """아래/하강/대쉬용 S/↓ 키인지 여부 (KEYDOWN/KEYUP용)"""
    if key_code in MOVE_DOWN_KEYS:
        return True
    if scancode is not None and scancode in MOVE_DOWN_SCANCODES:
        return True
    return False


def is_move_up_key(key_code: int, scancode: int | None = None) -> bool:
    """위/점프/특수 W/↑ 키인지 여부 (KEYDOWN/KEYUP용)"""
    if key_code in MOVE_UP_KEYS:
        return True
    if scancode is not None and scancode in MOVE_UP_SCANCODES:
        return True
    return False


def is_move_left_event(event) -> bool:
    """pygame 이벤트 객체가 왼쪽 이동 입력인지 확인."""
    if is_move_left_key(getattr(event, "key", None), getattr(event, "scancode", None)):
        return True
    uni = getattr(event, "unicode", None)
    if uni and uni in MOVE_LEFT_UNICODES:
        return True
    return False


def is_move_right_event(event) -> bool:
    """pygame 이벤트 객체가 오른쪽 이동 입력인지 확인."""
    if is_move_right_key(getattr(event, "key", None), getattr(event, "scancode", None)):
        return True
    uni = getattr(event, "unicode", None)
    if uni and uni in MOVE_RIGHT_UNICODES:
        return True
    return False


def is_move_down_event(event) -> bool:
    """pygame 이벤트 객체가 아래/대쉬(기본 S/↓) 입력인지 확인."""
    if is_move_down_key(getattr(event, "key", None), getattr(event, "scancode", None)):
        return True
    uni = getattr(event, "unicode", None)
    if uni and uni in MOVE_DOWN_UNICODES:
        return True
    return False


def is_move_up_event(event) -> bool:
    """pygame 이벤트 객체가 위/W/↑ 입력인지 확인."""
    if is_move_up_key(getattr(event, "key", None), getattr(event, "scancode", None)):
        return True
    uni = getattr(event, "unicode", None)
    if uni and uni in MOVE_UP_UNICODES:
        return True
    return False


def is_move_left_pressed(keys: Sequence[bool]) -> bool:
    """현재 프레임에서 왼쪽 이동 키가 눌려 있는지 확인 (keycode + scancode)"""
    if _any_move_left_pressed(keys):
        return True
    # 드물게 초기 프레임에서 키 상태가 비어 있는 경우 한 번 더 펌프 후 재조회
    try:
        pygame.event.pump()
        refreshed = pygame.key.get_pressed()
        if refreshed is not keys:
            if _any_move_left_pressed(refreshed):
                return True
    except Exception:
        pass
    if INPUT_DEBUG:
        global _last_debug_ms
        now = pygame.time.get_ticks() if pygame.get_init() else 0
        if now - _last_debug_ms >= 500:
            _last_debug_ms = now
            print(
                "[INPUT_DEBUG][LEFT]"
                f" focus={pygame.key.get_focused()}"
                f" K_LEFT={_safe_key_state(keys, pygame.K_LEFT)}"
                f" K_a={_safe_key_state(keys, pygame.K_a)}"
                f" 0x61={_safe_key_state(keys, 0x61)}"
                f" sc_left={_safe_key_state(keys, SCANCODE_LEFT_FALLBACK)}"
                f" sc_a={_safe_key_state(keys, SCANCODE_A_FALLBACK)}"
            )
    return False


def is_move_down_pressed(keys: Sequence[bool]) -> bool:
    """현재 프레임에서 아래/대쉬 키(S/↓)가 눌려 있는지 확인"""
    if _any_move_down_pressed(keys):
        return True
    try:
        pygame.event.pump()
        refreshed = pygame.key.get_pressed()
        if refreshed is not keys:
            if _any_move_down_pressed(refreshed):
                return True
    except Exception:
        pass
    if INPUT_DEBUG:
        global _last_debug_ms
        now = pygame.time.get_ticks() if pygame.get_init() else 0
        if now - _last_debug_ms >= 500:
            _last_debug_ms = now
            print(
                "[INPUT_DEBUG][DOWN]"
                f" focus={pygame.key.get_focused()}"
                f" K_DOWN={_safe_key_state(keys, pygame.K_DOWN)}"
                f" K_s={_safe_key_state(keys, pygame.K_s)}"
                f" 0x73={_safe_key_state(keys, 0x73)}"
                f" sc_down={_safe_key_state(keys, SCANCODE_DOWN_FALLBACK)}"
                f" sc_s={_safe_key_state(keys, SCANCODE_S_FALLBACK)}"
            )
    return False


def is_move_up_pressed(keys: Sequence[bool]) -> bool:
    """현재 프레임에서 위/W/↑ 키가 눌려 있는지 확인"""
    if _any_move_up_pressed(keys):
        return True
    try:
        pygame.event.pump()
        refreshed = pygame.key.get_pressed()
        if refreshed is not keys:
            if _any_move_up_pressed(refreshed):
                return True
    except Exception:
        pass
    if INPUT_DEBUG:
        global _last_debug_ms
        now = pygame.time.get_ticks() if pygame.get_init() else 0
        if now - _last_debug_ms >= 500:
            _last_debug_ms = now
            print(
                "[INPUT_DEBUG][UP]"
                f" focus={pygame.key.get_focused()}"
                f" K_UP={_safe_key_state(keys, pygame.K_UP)}"
                f" K_w={_safe_key_state(keys, pygame.K_w)}"
                f" 0x77={_safe_key_state(keys, 0x77)}"
                f" sc_up={_safe_key_state(keys, SCANCODE_UP_FALLBACK)}"
                f" sc_w={_safe_key_state(keys, SCANCODE_W_FALLBACK)}"
            )
    return False

def is_move_right_pressed(keys: Sequence[bool]) -> bool:
    """현재 프레임에서 오른쪽 이동 키가 눌려 있는지 확인 (keycode + scancode)"""
    if _any_move_right_pressed(keys):
        return True
    try:
        pygame.event.pump()
        refreshed = pygame.key.get_pressed()
        if refreshed is not keys:
            if _any_move_right_pressed(refreshed):
                return True
    except Exception:
        pass
    if INPUT_DEBUG:
        global _last_debug_ms
        now = pygame.time.get_ticks() if pygame.get_init() else 0
        if now - _last_debug_ms >= 500:
            _last_debug_ms = now
            print(
                "[INPUT_DEBUG][RIGHT]"
                f" focus={pygame.key.get_focused()}"
                f" K_RIGHT={_safe_key_state(keys, pygame.K_RIGHT)}"
                f" K_d={_safe_key_state(keys, pygame.K_d)}"
                f" 0x64={_safe_key_state(keys, 0x64)}"
                f" sc_right={_safe_key_state(keys, SCANCODE_RIGHT_FALLBACK)}"
                f" sc_d={_safe_key_state(keys, SCANCODE_D_FALLBACK)}"
            )
    return False
