"""Stages 패키지 초기화."""

from __future__ import annotations

from importlib import import_module
from typing import Any

__all__ = [
    "stage_loader",
    "stage7_boss",
]


def __getattr__(name: str) -> Any:
    if name in __all__:
        module = import_module(f"{__name__}.{name}")
        globals()[name] = module
        return module
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def __dir__() -> list[str]:
    return sorted(__all__)
