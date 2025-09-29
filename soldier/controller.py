from __future__ import annotations

from collections import UserList
from typing import Callable, Iterable


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
    """Manages the soldier's firearm inventory and related state."""

    def __init__(self, *, switch_cooldown_frames: int = 30, ui_highlight_duration: int = 180) -> None:
        self.switch_cooldown_frames = switch_cooldown_frames
        self.ui_highlight_duration = ui_highlight_duration

        self.weapons: WeaponInventory = WeaponInventory(self)
        self.current_index: int = 0
        self.switch_cooldown: int = 0
        self.reload_counts: dict[str, int] = {}
        self.degraded: set[str] = set()
        self.ui_highlight_timer: int = 0

    def on_inventory_changed(self) -> None:
        if not self.weapons:
            self.weapons.append("pistol")
        self.current_index = max(0, min(self.current_index, len(self.weapons) - 1))

    def reset_tracking(self, weapon_name: str) -> None:
        if weapon_name == "pistol":
            return
        self.reload_counts[weapon_name] = 0
        self.degraded.discard(weapon_name)

    def reset(self) -> None:
        self.weapons[:] = ["pistol"]
        self.current_index = 0
        self.switch_cooldown = 0
        self.reload_counts.clear()
        self.degraded.clear()
        self.ui_highlight_timer = 0

    def add_weapon(self, weapon_name: str, *, set_active: bool = True) -> bool:
        if weapon_name in self.weapons:
            return False
        self.weapons.append(weapon_name)
        self.reset_tracking(weapon_name)
        if set_active:
            self.current_index = len(self.weapons) - 1
            self.ui_highlight_timer = self.ui_highlight_duration
        return True

    def remove_weapon(self, weapon_name: str) -> None:
        if weapon_name not in self.weapons:
            return
        self.weapons.remove(weapon_name)
        self.reload_counts.pop(weapon_name, None)
        self.degraded.discard(weapon_name)
        if not self.weapons:
            self.weapons.append("pistol")
        self.current_index = max(0, min(self.current_index, len(self.weapons) - 1))

    def register_reload(self, weapon_name: str) -> bool:
        if weapon_name == "pistol":
            return False
        count = self.reload_counts.get(weapon_name, 0) + 1
        self.reload_counts[weapon_name] = count
        degradation_threshold = 2 if weapon_name == "fire_support" else 3
        if count >= degradation_threshold and weapon_name not in self.degraded:
            self.degraded.add(weapon_name)
            return True
        return False

    def check_degradation(
        self,
        *,
        get_bazooka_instance: Callable[[], object | None],
        get_ak47_instance: Callable[[], object | None],
        get_net_gun_instance: Callable[[], object | None],
        get_fire_support_instance: Callable[[], object | None],
    ) -> None:
        if "bazooka" in self.degraded:
            bazooka = get_bazooka_instance()
            if bazooka and getattr(bazooka, "ammo_count", 0) <= 0 and not getattr(bazooka, "projectiles", []):
                if hasattr(bazooka, "unequip"):
                    bazooka.unequip()
                if hasattr(bazooka, "max_ammo"):
                    bazooka.ammo_count = getattr(bazooka, "max_ammo", 0)
                self.remove_weapon("bazooka")
                print("⚠️ 바주카포 노후화로 파괴되었습니다.")

        if "ak47" in self.degraded:
            ak47 = get_ak47_instance()
            if ak47 and getattr(ak47, "active", False) and getattr(ak47, "current_ammo", 0) <= 0 and not getattr(ak47, "bullets", []):
                print("⚠️ AK-47 노후화 파괴 트리거", f"(bullets={len(getattr(ak47, 'bullets', []))}, remaining={getattr(ak47, 'remaining_time', 'N/A')})")
                if hasattr(ak47, "deactivate"):
                    ak47.deactivate()
                self.remove_weapon("ak47")
                print("⚠️ AK-47 노후화로 파괴되었습니다.")

        if "net_gun" in self.degraded:
            net_gun = get_net_gun_instance()
            if net_gun and getattr(net_gun, "ammo_count", 0) <= 0 and not getattr(net_gun, "projectiles", []) and not getattr(net_gun, "nets", []):
                if hasattr(net_gun, "unequip"):
                    net_gun.unequip()
                self.remove_weapon("net_gun")
                print("⚠️ 그물덫총 노후화로 파괴되었습니다.")

        if "fire_support" in self.degraded:
            fire_support = get_fire_support_instance()
            if fire_support:
                ammo_empty = getattr(fire_support, "ammo_count", 0) <= 0
                inactive = not getattr(fire_support, "strike_active", False) and not getattr(fire_support, "calling", False)
                no_bombs = not getattr(fire_support, "bombs", [])
                aircraft_clear = getattr(fire_support, "aircraft", None) is None
                if ammo_empty and inactive and no_bombs and aircraft_clear:
                    if hasattr(fire_support, "unequip"):
                        fire_support.unequip()
                    if hasattr(fire_support, "reset_runtime"):
                        fire_support.reset_runtime()
                    self.remove_weapon("fire_support")
                    print("⚠️ 화력지원 노후화로 폭격 지원 장비가 파괴되었습니다.")

    def set_current_weapon(self, index: int) -> None:
        if not self.weapons:
            return
        self.current_index = max(0, min(index, len(self.weapons) - 1))

    def next_weapon(self) -> str:
        if not self.weapons:
            return "pistol"
        self.current_index = (self.current_index + 1) % len(self.weapons)
        return self.weapons[self.current_index]

    def current_weapon(self) -> str:
        if not self.weapons:
            return "pistol"
        return self.weapons[self.current_index]
