"""Player-related state wrappers for legacy data access."""
from __future__ import annotations

from typing import Any

from core.legacy_state_accessor import LegacyStateAccessor


class RollingState:
    """Convenience wrapper around legacy dash/rolling globals."""

    def __init__(self, legacy: LegacyStateAccessor):
        self._legacy = legacy
        self._ensure_defaults()

    def _ensure_defaults(self) -> None:
        defaults = {
            "rolling_active": False,
            "rolling_timer": 0,
            "rolling_direction": 0,
            "rolling_speed": 30,
            "rolling_stun_timer": 0,
            "rolling_dash_available_timer": 0,
            "rolling_cooldown": 0,
            "rolling_charges": 1,
            "rolling_charge_timer": 0,
            "rolling_consecutive_count": 0,
            "rolling_consecutive_timer": 0,
            "token_states": [True],
        }
        for key, value in defaults.items():
            self._legacy.setdefault(key, value)

    def _get(self, key: str) -> Any:
        return getattr(self._legacy, key)

    def _set(self, key: str, value: Any) -> None:
        setattr(self._legacy, key, value)

    @property
    def active(self) -> bool:
        return bool(self._get("rolling_active"))

    @active.setter
    def active(self, value: bool) -> None:
        self._set("rolling_active", bool(value))

    @property
    def timer(self) -> int:
        return int(self._get("rolling_timer"))

    @timer.setter
    def timer(self, value: int) -> None:
        self._set("rolling_timer", int(value))

    @property
    def direction(self) -> int:
        return int(self._get("rolling_direction"))

    @direction.setter
    def direction(self, value: int) -> None:
        self._set("rolling_direction", int(value))

    @property
    def speed(self) -> float:
        return float(self._get("rolling_speed"))

    @speed.setter
    def speed(self, value: float) -> None:
        self._set("rolling_speed", float(value))

    @property
    def stun_timer(self) -> int:
        return int(self._get("rolling_stun_timer"))

    @stun_timer.setter
    def stun_timer(self, value: int) -> None:
        self._set("rolling_stun_timer", int(value))

    @property
    def available_timer(self) -> int:
        return int(self._get("rolling_dash_available_timer"))

    @available_timer.setter
    def available_timer(self, value: int) -> None:
        self._set("rolling_dash_available_timer", int(value))

    @property
    def cooldown(self) -> int:
        return int(self._get("rolling_cooldown"))

    @cooldown.setter
    def cooldown(self, value: int) -> None:
        self._set("rolling_cooldown", int(value))

    @property
    def charges(self) -> int:
        return int(self._get("rolling_charges"))

    @charges.setter
    def charges(self, value: int) -> None:
        self._set("rolling_charges", int(value))

    @property
    def charge_timer(self) -> int:
        return int(self._get("rolling_charge_timer"))

    @charge_timer.setter
    def charge_timer(self, value: int) -> None:
        self._set("rolling_charge_timer", int(value))

    @property
    def consecutive_count(self) -> int:
        return int(self._get("rolling_consecutive_count"))

    @consecutive_count.setter
    def consecutive_count(self, value: int) -> None:
        self._set("rolling_consecutive_count", int(value))

    @property
    def consecutive_timer(self) -> int:
        return int(self._get("rolling_consecutive_timer"))

    @consecutive_timer.setter
    def consecutive_timer(self, value: int) -> None:
        self._set("rolling_consecutive_timer", int(value))

    @property
    def token_states(self) -> list:
        return self._get("token_states")

    @token_states.setter
    def token_states(self, value: list) -> None:
        self._set("token_states", list(value))
