"""발토르(Blacksmith) 관련 런타임 상태 데이터 구조."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional, Sequence


@dataclass
class BlacksmithTurretRuntime:
    """포탑 시스템 런타임 상태."""

    active: bool = False
    blueprint_active: bool = False
    blueprint_rect: Any = None
    build_progress: int = 0
    state: Optional[dict[str, Any]] = None
    projectiles: list[dict[str, Any]] = field(default_factory=list)
    partial_drain: float = 0.0
    xp_partial_drain: float = 0.0
    manual_cooldown: int = 0
    overdrive_ui_timer: int = 0
    overdrive_ui_divine: bool = False


@dataclass
class BlacksmithDivineRuntime:
    """디바인 스톤 건설 상태."""

    state: Optional[dict[str, Any]] = None
    blueprint_active: bool = False
    blueprint_rect: Any = None
    build_progress: int = 0
    partial_drain: float = 0.0


@dataclass
class BlacksmithConstructionAudio:
    """건설 사운드 재생 상태."""

    playing: bool = False
    channel: Any = None


@dataclass
class BlacksmithState:
    """발토르 전용 런타임 상태 컨테이너."""

    turret: BlacksmithTurretRuntime = field(default_factory=BlacksmithTurretRuntime)
    divine: BlacksmithDivineRuntime = field(default_factory=BlacksmithDivineRuntime)
    down_hold_frames: int = 0
    build_menu_active: bool = False
    construction_audio: BlacksmithConstructionAudio = field(default_factory=BlacksmithConstructionAudio)

    def reset(self) -> None:
        """모든 상태를 초기화한다."""
        self.turret = BlacksmithTurretRuntime()
        self.divine = BlacksmithDivineRuntime()
        self.construction_audio = BlacksmithConstructionAudio()
        self.down_hold_frames = 0
        self.build_menu_active = False

    def apply_to_globals(self, namespace: Any, *, attrs: Optional[Sequence[str]] = None) -> None:
        """현재 상태를 pingfighter 전역 공간에 반영한다."""
        selected = set(attrs or (
            "blacksmith_turret_active",
            "blacksmith_turret_blueprint_active",
            "blacksmith_turret_blueprint_rect",
            "blacksmith_turret_build_progress",
            "blacksmith_turret_state",
            "blacksmith_turret_projectiles",
            "blacksmith_turret_partial_drain",
            "blacksmith_turret_xp_partial_drain",
            "blacksmith_turret_manual_cooldown",
            "blacksmith_turret_overdrive_ui_timer",
            "blacksmith_turret_overdrive_ui_divine",
            "blacksmith_divine_stone_state",
            "blacksmith_divine_blueprint_active",
            "blacksmith_divine_blueprint_rect",
            "blacksmith_divine_build_progress",
            "blacksmith_divine_partial_drain",
            "blacksmith_down_hold_frames",
            "blacksmith_build_menu_active",
            "blacksmith_construction_sound_playing",
            "blacksmith_construction_channel",
        ))

        turret = self.turret
        divine = self.divine
        construction = self.construction_audio

        if "blacksmith_turret_active" in selected:
            setattr(namespace, "blacksmith_turret_active", turret.active)
        if "blacksmith_turret_blueprint_active" in selected:
            setattr(namespace, "blacksmith_turret_blueprint_active", turret.blueprint_active)
        if "blacksmith_turret_blueprint_rect" in selected:
            setattr(namespace, "blacksmith_turret_blueprint_rect", turret.blueprint_rect)
        if "blacksmith_turret_build_progress" in selected:
            setattr(namespace, "blacksmith_turret_build_progress", turret.build_progress)
        if "blacksmith_turret_state" in selected:
            setattr(namespace, "blacksmith_turret_state", turret.state)
        if "blacksmith_turret_projectiles" in selected:
            setattr(namespace, "blacksmith_turret_projectiles", turret.projectiles)
        if "blacksmith_turret_partial_drain" in selected:
            setattr(namespace, "blacksmith_turret_partial_drain", turret.partial_drain)
        if "blacksmith_turret_xp_partial_drain" in selected:
            setattr(namespace, "blacksmith_turret_xp_partial_drain", turret.xp_partial_drain)
        if "blacksmith_turret_manual_cooldown" in selected:
            setattr(namespace, "blacksmith_turret_manual_cooldown", turret.manual_cooldown)
        if "blacksmith_turret_overdrive_ui_timer" in selected:
            setattr(namespace, "blacksmith_turret_overdrive_ui_timer", turret.overdrive_ui_timer)
        if "blacksmith_turret_overdrive_ui_divine" in selected:
            setattr(namespace, "blacksmith_turret_overdrive_ui_divine", turret.overdrive_ui_divine)

        if "blacksmith_divine_stone_state" in selected:
            setattr(namespace, "blacksmith_divine_stone_state", divine.state)
        if "blacksmith_divine_blueprint_active" in selected:
            setattr(namespace, "blacksmith_divine_blueprint_active", divine.blueprint_active)
        if "blacksmith_divine_blueprint_rect" in selected:
            setattr(namespace, "blacksmith_divine_blueprint_rect", divine.blueprint_rect)
        if "blacksmith_divine_build_progress" in selected:
            setattr(namespace, "blacksmith_divine_build_progress", divine.build_progress)
        if "blacksmith_divine_partial_drain" in selected:
            setattr(namespace, "blacksmith_divine_partial_drain", divine.partial_drain)

        if "blacksmith_down_hold_frames" in selected:
            setattr(namespace, "blacksmith_down_hold_frames", self.down_hold_frames)
        if "blacksmith_build_menu_active" in selected:
            setattr(namespace, "blacksmith_build_menu_active", self.build_menu_active)
        if "blacksmith_construction_sound_playing" in selected:
            setattr(namespace, "blacksmith_construction_sound_playing", construction.playing)
        if "blacksmith_construction_channel" in selected:
            setattr(namespace, "blacksmith_construction_channel", construction.channel)

    def sync_from_globals(self, namespace: Any, *, attrs: Optional[Sequence[str]] = None) -> None:
        """pingfighter 전역 상태를 현재 객체에 반영한다."""
        selected = set(attrs or (
            "blacksmith_turret_active",
            "blacksmith_turret_blueprint_active",
            "blacksmith_turret_blueprint_rect",
            "blacksmith_turret_build_progress",
            "blacksmith_turret_state",
            "blacksmith_turret_projectiles",
            "blacksmith_turret_partial_drain",
            "blacksmith_turret_xp_partial_drain",
            "blacksmith_turret_manual_cooldown",
            "blacksmith_turret_overdrive_ui_timer",
            "blacksmith_turret_overdrive_ui_divine",
            "blacksmith_divine_stone_state",
            "blacksmith_divine_blueprint_active",
            "blacksmith_divine_blueprint_rect",
            "blacksmith_divine_build_progress",
            "blacksmith_divine_partial_drain",
            "blacksmith_down_hold_frames",
            "blacksmith_build_menu_active",
            "blacksmith_construction_sound_playing",
            "blacksmith_construction_channel",
        ))

        turret = self.turret
        divine = self.divine
        construction = self.construction_audio

        if "blacksmith_turret_active" in selected:
            turret.active = bool(getattr(namespace, "blacksmith_turret_active", False))
        if "blacksmith_turret_blueprint_active" in selected:
            turret.blueprint_active = bool(getattr(namespace, "blacksmith_turret_blueprint_active", False))
        if "blacksmith_turret_blueprint_rect" in selected:
            turret.blueprint_rect = getattr(namespace, "blacksmith_turret_blueprint_rect", None)
        if "blacksmith_turret_build_progress" in selected:
            turret.build_progress = int(getattr(namespace, "blacksmith_turret_build_progress", 0))
        if "blacksmith_turret_state" in selected:
            turret.state = getattr(namespace, "blacksmith_turret_state", None)
        if "blacksmith_turret_projectiles" in selected:
            turret.projectiles = list(getattr(namespace, "blacksmith_turret_projectiles", []))
        if "blacksmith_turret_partial_drain" in selected:
            turret.partial_drain = float(getattr(namespace, "blacksmith_turret_partial_drain", 0.0))
        if "blacksmith_turret_xp_partial_drain" in selected:
            turret.xp_partial_drain = float(getattr(namespace, "blacksmith_turret_xp_partial_drain", 0.0))
        if "blacksmith_turret_manual_cooldown" in selected:
            turret.manual_cooldown = int(getattr(namespace, "blacksmith_turret_manual_cooldown", 0))
        if "blacksmith_turret_overdrive_ui_timer" in selected:
            turret.overdrive_ui_timer = int(getattr(namespace, "blacksmith_turret_overdrive_ui_timer", 0))
        if "blacksmith_turret_overdrive_ui_divine" in selected:
            turret.overdrive_ui_divine = bool(getattr(namespace, "blacksmith_turret_overdrive_ui_divine", False))

        if "blacksmith_divine_stone_state" in selected:
            divine.state = getattr(namespace, "blacksmith_divine_stone_state", None)
        if "blacksmith_divine_blueprint_active" in selected:
            divine.blueprint_active = bool(getattr(namespace, "blacksmith_divine_blueprint_active", False))
        if "blacksmith_divine_blueprint_rect" in selected:
            divine.blueprint_rect = getattr(namespace, "blacksmith_divine_blueprint_rect", None)
        if "blacksmith_divine_build_progress" in selected:
            divine.build_progress = int(getattr(namespace, "blacksmith_divine_build_progress", 0))
        if "blacksmith_divine_partial_drain" in selected:
            divine.partial_drain = float(getattr(namespace, "blacksmith_divine_partial_drain", 0.0))

        if "blacksmith_down_hold_frames" in selected:
            self.down_hold_frames = int(getattr(namespace, "blacksmith_down_hold_frames", 0))
        if "blacksmith_build_menu_active" in selected:
            self.build_menu_active = bool(getattr(namespace, "blacksmith_build_menu_active", False))
        if "blacksmith_construction_sound_playing" in selected:
            construction.playing = bool(getattr(namespace, "blacksmith_construction_sound_playing", False))
        if "blacksmith_construction_channel" in selected:
            construction.channel = getattr(namespace, "blacksmith_construction_channel", None)


blacksmith_state = BlacksmithState()

__all__ = [
    "BlacksmithState",
    "BlacksmithTurretRuntime",
    "BlacksmithDivineRuntime",
    "BlacksmithConstructionAudio",
    "blacksmith_state",
]
