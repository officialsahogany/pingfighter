from __future__ import annotations

from collections import UserList
from typing import Iterable


class WeaponInventory(UserList[str]):
    """List-like container that keeps the controller in sync."""

    def __init__(self, controller: "SoldierWeaponController", initial: Iterable[str] | None = None) -> None:
        super().__init__(initial or ["pistol"])
        self._controller = controller

    def append(self, item: str) -> None:  # type: ignore[override]
        super().append(item)
        self._controller.on_inventory_changed()

    def remove(self, item: str) -> None:  # type: ignore[override]
        super().remove(item)
        self._controller.on_inventory_changed()

    def insert(self, index: int, item: str) -> None:  # type: ignore[override]
        super().insert(index, item)
        self._controller.on_inventory_changed()

    def clear(self) -> None:  # type: ignore[override]
        super().clear()
        self._controller.on_inventory_changed()


class SoldierWeaponController:
    """Manages the soldier's firearm inventory and related state.

    Canonical state is split into:
    - permanent_owned: permanently unlocked firearms for the run
    - equipped_permanent: currently orb-equipped permanent firearms
    - rental_weapons: temporary stage-local firearms from supply drops

    `weapons` stays as the live derived list used by legacy runtime paths:
    `["pistol"] + equipped_permanent + rental_weapons`.
    """

    def __init__(self, *, switch_cooldown_frames: int = 30, ui_highlight_duration: int = 180) -> None:
        self.switch_cooldown_frames = switch_cooldown_frames
        self.ui_highlight_duration = ui_highlight_duration

        self.weapons: WeaponInventory = WeaponInventory(self)
        self.current_index: int = 0
        self.switch_cooldown: int = 0
        self.reload_counts: dict[str, int] = {}
        self.degradation_thresholds: dict[str, int] = {}
        # Backward-compatibility alias: rentals are tracked as "degraded".
        self.degraded: set[str] = set()
        self.ui_highlight_timer: int = 0

        self.permanent_owned: set[str] = set()
        self.equipped_permanent: list[str] = []
        self.rental_weapons: dict[str, dict[str, int | str | None]] = {}

        self.rebuild_inventory(set_active="pistol")

    def on_inventory_changed(self) -> None:
        if not self.weapons:
            self.weapons.data[:] = ["pistol"]
        self.current_index = max(0, min(self.current_index, len(self.weapons) - 1))

    def current_weapon(self) -> str:
        if not self.weapons:
            return "pistol"
        return self.weapons[self.current_index]

    def _normalize_state(self) -> None:
        self.equipped_permanent = [
            weapon_name
            for weapon_name in self.equipped_permanent
            if weapon_name in self.permanent_owned
        ]

        for weapon_name in list(self.rental_weapons.keys()):
            if weapon_name in self.permanent_owned:
                self.rental_weapons.pop(weapon_name, None)

        rental_names = set(self.rental_weapons.keys())
        self.degraded.intersection_update(rental_names)
        self.reload_counts = {
            weapon_name: count
            for weapon_name, count in self.reload_counts.items()
            if weapon_name in self.permanent_owned or weapon_name in rental_names
        }
        self.degradation_thresholds = {
            weapon_name: threshold
            for weapon_name, threshold in self.degradation_thresholds.items()
            if weapon_name in rental_names
        }

        for weapon_name in rental_names:
            self.reload_counts.setdefault(weapon_name, 0)
            self.degradation_thresholds.setdefault(weapon_name, 0)

    def rebuild_inventory(self, *, set_active: str | None = None) -> None:
        previous_weapon = set_active or self.current_weapon()
        self._normalize_state()

        derived = ["pistol"]
        derived.extend(
            weapon_name
            for weapon_name in self.equipped_permanent
            if weapon_name in self.permanent_owned and weapon_name != "pistol"
        )
        derived.extend(
            weapon_name
            for weapon_name in self.rental_weapons.keys()
            if weapon_name not in derived and weapon_name != "pistol"
        )

        self.weapons.data[:] = derived or ["pistol"]
        if previous_weapon in self.weapons:
            self.current_index = self.weapons.index(previous_weapon)
        else:
            self.current_index = 0
        self.on_inventory_changed()

    def reset_tracking(self, weapon_name: str) -> None:
        if weapon_name == "pistol":
            return
        self.reload_counts[weapon_name] = 0
        if weapon_name in self.rental_weapons:
            self.degradation_thresholds[weapon_name] = 0
            self.degraded.add(weapon_name)
        else:
            self.degradation_thresholds.pop(weapon_name, None)
            self.degraded.discard(weapon_name)

    def reset(self) -> None:
        self.permanent_owned.clear()
        self.equipped_permanent.clear()
        self.rental_weapons.clear()
        self.weapons.data[:] = ["pistol"]
        self.current_index = 0
        self.switch_cooldown = 0
        self.reload_counts.clear()
        self.degradation_thresholds.clear()
        self.degraded.clear()
        self.ui_highlight_timer = 0

    def unlock_permanent_weapon(self, weapon_name: str, *, set_active: bool = True) -> bool:
        if weapon_name == "pistol":
            return False

        added = weapon_name not in self.permanent_owned
        self.permanent_owned.add(weapon_name)
        self.rental_weapons.pop(weapon_name, None)
        self.degraded.discard(weapon_name)
        self.degradation_thresholds.pop(weapon_name, None)
        self.reload_counts.setdefault(weapon_name, 0)
        self.rebuild_inventory(set_active=weapon_name if set_active else None)
        if set_active and weapon_name in self.weapons:
            self.ui_highlight_timer = self.ui_highlight_duration
        return added

    def set_equipped_permanent(self, weapon_names: Iterable[str], *, set_active: str | None = None) -> None:
        self.equipped_permanent = [
            weapon_name
            for weapon_name in weapon_names
            if weapon_name in self.permanent_owned and weapon_name != "pistol"
        ]
        self.rebuild_inventory(set_active=set_active)

    def add_weapon(
        self,
        weapon_name: str,
        *,
        set_active: bool = True,
        kind: str = "rental",
        acquired_stage: int | None = None,
    ) -> bool:
        if kind == "owned":
            return self.unlock_permanent_weapon(weapon_name, set_active=set_active)
        return self.grant_rental_weapon(
            weapon_name,
            acquired_stage=acquired_stage,
            set_active=set_active,
        )

    def grant_rental_weapon(
        self,
        weapon_name: str,
        *,
        acquired_stage: int | None = None,
        set_active: bool = True,
    ) -> bool:
        if weapon_name == "pistol":
            return False
        if weapon_name in self.permanent_owned or weapon_name in self.rental_weapons:
            return False

        self.rental_weapons[weapon_name] = {
            "kind": "rental",
            "acquired_stage": acquired_stage,
        }
        self.reset_tracking(weapon_name)
        self.rebuild_inventory(set_active=weapon_name if set_active else None)
        if set_active and weapon_name in self.weapons:
            self.ui_highlight_timer = self.ui_highlight_duration
        return True

    def remove_weapon(self, weapon_name: str) -> None:
        if weapon_name == "pistol":
            return

        if weapon_name in self.rental_weapons:
            self.rental_weapons.pop(weapon_name, None)
        if weapon_name in self.permanent_owned:
            self.permanent_owned.discard(weapon_name)
            self.equipped_permanent = [
                skill_name for skill_name in self.equipped_permanent if skill_name != weapon_name
            ]

        self.reload_counts.pop(weapon_name, None)
        self.degradation_thresholds.pop(weapon_name, None)
        self.degraded.discard(weapon_name)
        self.rebuild_inventory()

    def remove_rental_weapon(self, weapon_name: str) -> bool:
        if weapon_name not in self.rental_weapons:
            return False
        self.rental_weapons.pop(weapon_name, None)
        self.reload_counts.pop(weapon_name, None)
        self.degradation_thresholds.pop(weapon_name, None)
        self.degraded.discard(weapon_name)
        self.rebuild_inventory()
        return True

    def release_rental_if_depleted(
        self,
        weapon_name: str,
        *,
        current_ammo: int | None = None,
    ) -> bool:
        if weapon_name not in self.rental_weapons:
            return False
        if current_ammo is None or current_ammo > 0:
            return False

        previous_weapon = self.current_weapon()
        self.rental_weapons.pop(weapon_name, None)
        self.reload_counts.pop(weapon_name, None)
        self.degradation_thresholds.pop(weapon_name, None)
        self.degraded.discard(weapon_name)
        fallback_weapon = "pistol" if previous_weapon == weapon_name else previous_weapon
        self.rebuild_inventory(set_active=fallback_weapon)
        return True

    def remove_expired_rentals(self, current_stage: int) -> list[str]:
        removed: list[str] = []
        for weapon_name, metadata in list(self.rental_weapons.items()):
            acquired_stage = metadata.get("acquired_stage")
            if isinstance(acquired_stage, int) and acquired_stage < current_stage:
                self.rental_weapons.pop(weapon_name, None)
                self.reload_counts.pop(weapon_name, None)
                self.degradation_thresholds.pop(weapon_name, None)
                self.degraded.discard(weapon_name)
                removed.append(weapon_name)
        if removed:
            self.rebuild_inventory()
        return removed

    def is_rental_weapon(self, weapon_name: str) -> bool:
        return weapon_name in self.rental_weapons

    def is_permanent_weapon(self, weapon_name: str) -> bool:
        return weapon_name in self.permanent_owned

    def get_weapon_kind(self, weapon_name: str) -> str:
        if weapon_name == "pistol":
            return "base"
        if weapon_name in self.permanent_owned:
            return "owned"
        if weapon_name in self.rental_weapons:
            return "rental"
        return "unknown"

    def register_reload(self, weapon_name: str) -> bool:
        if weapon_name == "pistol":
            return False
        self.reload_counts[weapon_name] = self.reload_counts.get(weapon_name, 0) + 1
        # Permanent firearms no longer degrade; rentals are tracked separately
        # and expire on stage transition instead of on reload count.
        return False

    def check_degradation(self, **_: object) -> None:
        """Backward-compatible no-op.

        The old "degradation" lifecycle has been replaced by stage-local
        rentals, so runtime removal no longer happens on reload counts.
        """

    def set_current_weapon(self, index: int) -> None:
        if not self.weapons:
            return
        self.current_index = max(0, min(index, len(self.weapons) - 1))

    def next_weapon(self) -> str:
        if not self.weapons:
            return "pistol"
        self.current_index = (self.current_index + 1) % len(self.weapons)
        return self.weapons[self.current_index]
