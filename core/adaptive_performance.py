"""Adaptive performance helpers for runtime frame pacing."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from typing import Deque


LEVEL_NORMAL = "normal"
LEVEL_WARNING = "warning"
LEVEL_CRITICAL = "critical"


@dataclass(frozen=True)
class PerformanceSnapshot:
    """Runtime performance summary."""

    average_fps: float
    average_frame_time_ms: float
    level: str
    pressure: float
    stress_score: float


class AdaptivePerformanceController:
    """Tracks sustained frame pressure and exposes a coarse quality level."""

    def __init__(self, target_fps: int = 60, enabled: bool = True, history_size: int = 45):
        self.target_fps = max(30, int(target_fps))
        self.enabled = bool(enabled)
        self._history: Deque[float] = deque(maxlen=max(15, int(history_size)))
        self._stress_score = 0.0
        self._average_fps = float(self.target_fps)
        self._average_frame_time_ms = 1000.0 / self.target_fps
        self._pressure = 1.0
        self._level = LEVEL_NORMAL

    @property
    def average_fps(self) -> float:
        return self._average_fps

    @property
    def average_frame_time_ms(self) -> float:
        return self._average_frame_time_ms

    @property
    def pressure(self) -> float:
        return self._pressure

    @property
    def stress_score(self) -> float:
        return self._stress_score

    @property
    def level(self) -> str:
        return self._level

    def set_enabled(self, enabled: bool) -> None:
        enabled = bool(enabled)
        if self.enabled == enabled:
            return
        self.enabled = enabled
        if not enabled:
            self._stress_score = 0.0
            self._level = LEVEL_NORMAL

    def reset(self) -> None:
        self._history.clear()
        self._stress_score = 0.0
        self._average_fps = float(self.target_fps)
        self._average_frame_time_ms = 1000.0 / self.target_fps
        self._pressure = 1.0
        self._level = LEVEL_NORMAL

    def update(self, dt_ms: float) -> PerformanceSnapshot:
        dt_ms = max(1.0, min(float(dt_ms), 250.0))
        self._history.append(dt_ms)

        self._average_frame_time_ms = sum(self._history) / len(self._history)
        self._average_fps = (
            1000.0 / self._average_frame_time_ms if self._average_frame_time_ms > 0 else float(self.target_fps)
        )

        target_frame_time_ms = 1000.0 / self.target_fps
        self._pressure = self._average_frame_time_ms / target_frame_time_ms

        if self.enabled:
            self._apply_pressure(dt_ms, target_frame_time_ms)
        else:
            self._stress_score = 0.0
            self._level = LEVEL_NORMAL

        return PerformanceSnapshot(
            average_fps=self._average_fps,
            average_frame_time_ms=self._average_frame_time_ms,
            level=self._level,
            pressure=self._pressure,
            stress_score=self._stress_score,
        )

    def _apply_pressure(self, dt_ms: float, target_frame_time_ms: float) -> None:
        pressure = self._pressure

        if dt_ms <= target_frame_time_ms * 1.02:
            if pressure <= 1.15:
                self._stress_score = max(0.0, self._stress_score - 0.08)
            elif pressure <= 1.30:
                self._stress_score = max(0.0, self._stress_score - 0.04)
            else:
                self._stress_score = max(0.0, self._stress_score - 0.02)
        elif pressure >= 1.45 or dt_ms >= target_frame_time_ms * 2.2:
            self._stress_score = min(1.0, self._stress_score + 0.22)
        elif pressure >= 1.20:
            self._stress_score = min(1.0, self._stress_score + 0.10)
        elif pressure >= 1.05:
            self._stress_score = min(1.0, self._stress_score + 0.04)
        elif pressure <= 0.90:
            self._stress_score = max(0.0, self._stress_score - 0.12)
        elif pressure <= 0.97:
            self._stress_score = max(0.0, self._stress_score - 0.05)
        else:
            self._stress_score = max(0.0, self._stress_score - 0.02)

        if self._stress_score >= 0.70:
            self._level = LEVEL_CRITICAL
        elif self._stress_score >= 0.25:
            self._level = LEVEL_WARNING
        else:
            self._level = LEVEL_NORMAL
