"""BossPong 테스트 스위트 초기화 모듈."""

from __future__ import annotations

import os
import sys
from typing import Final

# 프로젝트 루트를 Python 경로에 추가
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

__all__ = ["init_headless_environment"]

_HEADLESS_FLAG: Final[str] = "BOSSPONG_TEST_HEADLESS_INIT"
_VERBOSE_FLAG: Final[str] = "BOSSPONG_TEST_VERBOSE"


def _ensure_headless_env() -> None:
    """SDL 드라이버를 헤드리스용 더미 드라이버로 설정한다."""

    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    os.environ.setdefault("SDL_AUDIODRIVER", "dummy")


def _ensure_pygame_initialized() -> None:
    """필요 시 pygame을 초기화한다."""

    try:
        import pygame
    except ImportError:
        return

    if not pygame.get_init():
        pygame.init()


def init_headless_environment(*, verbose: bool | None = None) -> None:
    """외부에서 호출 가능한 헤드리스 초기화 헬퍼."""

    _ensure_headless_env()
    _ensure_pygame_initialized()

    if verbose or (verbose is None and os.environ.get(_VERBOSE_FLAG) == "1"):
        print("🧪 BossPong 테스트 스위트 초기화 완료 (headless)")


if os.environ.get(_HEADLESS_FLAG, "1") == "1":
    init_headless_environment()
