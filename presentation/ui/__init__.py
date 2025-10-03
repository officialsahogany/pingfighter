"""지연 로딩 기반 UI 패키지 초기화.

레거시 구조에서는 ``from presentation.ui import *`` 패턴이 흔했으나,
이 경우 서브모듈 임포트 시점에 `items` 등의 무거운 리소스가 즉시 로드되어
헤드리스 환경에서 충돌을 일으키곤 했다. 지연 로딩을 도입해 필요한 경우에만
서브모듈을 불러오도록 변경한다.
"""

from __future__ import annotations

from importlib import import_module
from typing import Any

__all__ = ["menus", "hud", "dialogs", "effects"]


def __getattr__(name: str) -> Any:
    """요청된 서브모듈을 최초 접근 시 임포트한다."""

    if name in __all__:
        module = import_module(f"{__name__}.{name}")
        globals()[name] = module
        return module
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def __dir__() -> list[str]:
    return sorted(__all__)
