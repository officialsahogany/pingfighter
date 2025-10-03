"""게임 런타임 전역 상태 패키지.

pingfighter.py에 흩어져 있는 전역 상태를 단계적으로 모듈화하기 위한 네임스페이스.
각 서브모듈은 특정 도메인(오디오, 아이템 등)의 상태와 헬퍼 유틸을 제공합니다.
"""

from __future__ import annotations

from importlib import import_module
from typing import Any, Dict, Tuple

__all__ = [
    "audio",
    "items",
    "ItemStateAdapter",
    "item_state",
    "bind_item_state",
    "unbind_item_state",
]

_SUBMODULE_EXPORTS: Dict[str, Tuple[str, str]] = {
    "ItemStateAdapter": ("items", "ItemStateAdapter"),
    "item_state": ("items", "item_state"),
    "bind_item_state": ("items", "bind_item_state"),
    "unbind_item_state": ("items", "unbind_item_state"),
}


def __getattr__(name: str) -> Any:
    if name in ("audio", "items"):
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
