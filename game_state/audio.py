"""오디오 볼륨 관련 런타임 상태와 헬퍼.

pingfighter.py에서 전역으로 관리하던 BGM/SFX 볼륨 값을
단일 데이터 클래스로 묶어 모듈 단위 접근을 가능하게 한다.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict

__all__ = [
    "AudioSettings",
    "audio_settings",
    "clamp_volume",
    "get_bgm_volume",
    "get_sfx_volume",
    "set_bgm_volume",
    "set_sfx_volume",
    "get_bgm_muted",
    "set_bgm_muted",
    "get_sfx_muted",
    "set_sfx_muted",
    "export_audio_state",
    "load_audio_state",
    "resolve_runtime_bgm_volume",
]


@dataclass(slots=True)
class AudioSettings:
    """게임 전역의 오디오 볼륨 상태."""

    bgm_volume: float = 0.4
    sfx_volume: float = 0.7
    bgm_muted: bool = False
    sfx_muted: bool = False

    def set_bgm(self, value: float) -> float:
        self.bgm_volume = clamp_volume(value)
        return self.bgm_volume

    def set_sfx(self, value: float) -> float:
        self.sfx_volume = clamp_volume(value)
        return self.sfx_volume


audio_settings = AudioSettings()


def clamp_volume(value: float) -> float:
    """0.0~1.0 범위로 볼륨 값을 고정."""

    if value < 0.0:
        return 0.0
    if value > 1.0:
        return 1.0
    return value


def get_bgm_volume() -> float:
    """현재 저장된 BGM 볼륨."""

    return audio_settings.bgm_volume


def get_sfx_volume() -> float:
    """현재 저장된 SFX 볼륨."""

    return audio_settings.sfx_volume


def set_bgm_volume(value: float) -> float:
    """BGM 볼륨을 갱신하고 정규화된 값을 반환."""

    return audio_settings.set_bgm(value)


def set_sfx_volume(value: float) -> float:
    """SFX 볼륨을 갱신하고 정규화된 값을 반환."""

    return audio_settings.set_sfx(value)


def get_bgm_muted() -> bool:
    """BGM 음소거 상태."""
    return audio_settings.bgm_muted


def set_bgm_muted(muted: bool) -> bool:
    """BGM 음소거 상태 설정."""
    audio_settings.bgm_muted = muted
    return muted


def get_sfx_muted() -> bool:
    """SFX 음소거 상태."""
    return audio_settings.sfx_muted


def set_sfx_muted(muted: bool) -> bool:
    """SFX 음소거 상태 설정."""
    audio_settings.sfx_muted = muted
    return muted


def export_audio_state() -> Dict[str, Any]:
    """외부 저장용 딕셔너리로 직렬화."""

    return {
        "bgm_volume": audio_settings.bgm_volume,
        "sfx_volume": audio_settings.sfx_volume,
        "bgm_muted": audio_settings.bgm_muted,
        "sfx_muted": audio_settings.sfx_muted,
    }


def load_audio_state(data: Dict[str, Any]) -> AudioSettings:
    """저장된 볼륨 값을 불러와 상태를 복원."""

    if "bgm_volume" in data:
        audio_settings.set_bgm(data["bgm_volume"])
    if "sfx_volume" in data:
        audio_settings.set_sfx(data["sfx_volume"])
    if "bgm_muted" in data:
        audio_settings.bgm_muted = bool(data["bgm_muted"])
    if "sfx_muted" in data:
        audio_settings.sfx_muted = bool(data["sfx_muted"])
    return audio_settings


def resolve_runtime_bgm_volume(manager: Any, fallback: float) -> float:
    """BGM 매니저 객체가 보유한 실시간 볼륨을 안전하게 추출."""

    volume = getattr(manager, "volume", None)
    if isinstance(volume, (int, float)):
        return clamp_volume(volume)
    return clamp_volume(fallback)
