"""Core 패키지 초기화.

핵심 시스템 모듈을 필요한 시점에만 임포트하도록 지연 로딩을 사용한다.
"""

from __future__ import annotations

from importlib import import_module
from typing import Any, Dict, Tuple

__all__ = [
    "game_engine",
    "game_state",
    "events",
    "event_bus",
    "legacy_bridge",
    "GameEngine",
]

_SUBMODULE_EXPORTS: Dict[str, Tuple[str, str]] = {
    "GameEngine": ("game_engine", "GameEngine"),
}


def __getattr__(name: str) -> Any:
    if name in {"game_engine", "game_state", "events", "event_bus", "legacy_bridge"}:
        module = import_module(f"{__name__}.{name}")
        globals()[name] = module
        return module

    if name in _SUBMODULE_EXPORTS:
        module_name, attr_name = _SUBMODULE_EXPORTS[name]
        module = import_module(f"{__name__}.{module_name}")
        value = getattr(module, attr_name)
        globals()[name] = value
        return value

    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def __dir__() -> list[str]:
    return sorted(__all__)
