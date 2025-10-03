"""아이템 효과 패키지 초기화.

아이템 효과 모듈들은 리소스를 다루는 경우가 많아 필요 시점에만 임포트되도록
지연 로딩을 도입한다. 레거시 사용처에서 기대하던
``from item_effects import DowsingPendulumEffect`` 패턴도 계속 지원한다.
"""

from __future__ import annotations

from importlib import import_module
from typing import Any, Dict, Tuple

__all__ = [
    "ak47",
    "ammo_box",
    "bazooka",
    "bluetooth_ring",
    "devil_dice",
    "dowsing_pendulum",
    "fire_support",
    "foul_whistle",
    "fuel_pouch",
    "knee_pads",
    "net_gun",
    "smartphone",
    "star_detector",
    "technical_vest",
]

_LEGACY_EXPORTS: Dict[str, Tuple[str, str]] = {
    "DowsingPendulumEffect": ("dowsing_pendulum", "DowsingPendulumEffect"),
}


def __getattr__(name: str) -> Any:
    if name in __all__:
        module = import_module(f"{__name__}.{name}")
        globals()[name] = module
        return module

    if name in _LEGACY_EXPORTS:
        module_name, attr_name = _LEGACY_EXPORTS[name]
        module = import_module(f"{__name__}.{module_name}")
        value = getattr(module, attr_name)
        globals()[name] = value
        return value

    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


def __dir__() -> list[str]:
    return sorted({*__all__, *(_LEGACY_EXPORTS.keys())})
