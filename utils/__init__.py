"""공용 유틸리티 패키지.

자주 참조되는 유틸리티 모듈을 지연 로딩으로 노출한다.
"""

from __future__ import annotations

from importlib import import_module
from typing import Any

__all__ = [
    "color_utils",
    "math_utils",
    "draw_utils",
    "particle_utils",
    "game_constants",
    "game_helpers",
    "render_utils",
]


def __getattr__(name: str) -> Any:
    if name in __all__:
        module = import_module(f"{__name__}.{name}")
        globals()[name] = module
        return module
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def __dir__() -> list[str]:
    return sorted(__all__)
