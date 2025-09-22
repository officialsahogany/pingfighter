"""오디오 볼륨 관련 런타임 상태와 헬퍼.

pingfighter.py에서 전역으로 관리하던 BGM/SFX 볼륨 값을
단일 데이터 클래스로 묶어 모듈 단위 접근을 가능하게 한다.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict

__all__ = [
    "AudioSettings",
    "audio_settings",
    "clamp_volume",
    "get_bgm_volume",
    "get_sfx_volume",
    "set_bgm_volume",
    "set_sfx_volume",
    "export_audio_state",
    "load_audio_state",
]


@dataclass(slots=True)
class AudioSettings:
    """게임 전역의 오디오 볼륨 상태."""

    bgm_volume: float = 0.4
    sfx_volume: float = 0.7

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


def export_audio_state() -> Dict[str, float]:
    """외부 저장용 딕셔너리로 직렬화."""

    return {
        "bgm_volume": audio_settings.bgm_volume,
        "sfx_volume": audio_settings.sfx_volume,
    }


def load_audio_state(data: Dict[str, float]) -> AudioSettings:
    """저장된 볼륨 값을 불러와 상태를 복원."""

    if "bgm_volume" in data:
        audio_settings.set_bgm(data["bgm_volume"])
    if "sfx_volume" in data:
        audio_settings.set_sfx(data["sfx_volume"])
    return audio_settings
