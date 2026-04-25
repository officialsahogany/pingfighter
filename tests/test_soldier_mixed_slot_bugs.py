import math
import os
from types import SimpleNamespace

import pytest


os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
os.environ.setdefault("PINGFIGHTER_SMOKE_TEST", "1")

import pingfighter


@pytest.fixture()
def soldier_state_snapshot():
    controller = pingfighter.soldier_controller
    snapshot = {
        "runtime_skill_levels": dict(pingfighter.runtime_skill_levels),
        "soldier_equipped": list(pingfighter._soldier_equipped_skills),
        "soldier_unlocked": dict(pingfighter._soldier_skill_unlocked),
        "soldier_weapon_unlocks": dict(pingfighter.soldier_weapon_unlocks),
        "controller_permanent": set(controller.permanent_owned),
        "controller_equipped": list(controller.equipped_permanent),
        "controller_rentals": dict(controller.rental_weapons),
        "controller_weapons": list(controller.weapons),
        "controller_index": controller.current_index,
    }
    yield
    pingfighter.runtime_skill_levels.clear()
    pingfighter.runtime_skill_levels.update(snapshot["runtime_skill_levels"])
    pingfighter._soldier_equipped_skills = snapshot["soldier_equipped"]
    pingfighter._soldier_skill_unlocked = snapshot["soldier_unlocked"]
    pingfighter.soldier_weapon_unlocks = snapshot["soldier_weapon_unlocks"]
    controller.permanent_owned = snapshot["controller_permanent"]
    controller.equipped_permanent = snapshot["controller_equipped"]
    controller.rental_weapons = snapshot["controller_rentals"]
    controller.weapons.data[:] = snapshot["controller_weapons"]
    controller.current_index = snapshot["controller_index"]


@pytest.mark.parametrize(
    ("skill_name", "cooldown_attr"),
    (
        ("bazooka", "COOLDOWN_TIME"),
        ("ak47", "fire_interval"),
        ("net_gun", "COOLDOWN_FRAMES"),
        ("bowling_trap", "COOLDOWN_FRAMES"),
    ),
)
def test_soldier_firearm_instance_cooldowns_share_reduction_path(
    monkeypatch,
    skill_name,
    cooldown_attr,
):
    assert pingfighter._SOLDIER_ORB_ICON_REGISTRY[skill_name]["cooldown_reduction_eligible"]

    def half_cooldown(base_seconds):
        return float(base_seconds) * 0.5

    monkeypatch.setattr(
        pingfighter,
        "_get_effective_player_skill_cooldown_seconds",
        half_cooldown,
    )
    instance = SimpleNamespace(
        COOLDOWN_TIME=999,
        COOLDOWN_FRAMES=999,
        fire_interval=999,
    )

    frames = pingfighter._apply_soldier_firearm_cooldown_frames(
        skill_name,
        instance,
        apply_reduction=True,
    )

    expected = max(
        1,
        int(math.ceil(pingfighter.PERMANENT_FIREARM_COOLDOWNS[skill_name] * 0.5 * pingfighter.FPS)),
    )
    assert frames == expected
    assert getattr(instance, cooldown_attr) == expected


def test_heavenly_cape_soldier_overflow_uses_shared_cleanup(soldier_state_snapshot):
    victim = "net_gun"
    victim_perk = "soldier_unlock_net_gun"
    pingfighter._soldier_equipped_skills = list(pingfighter.SOLDIER_BASE_SKILLS) + [
        "fire_support",
        "bowling_trap",
        "suicide_drone",
        victim,
    ]
    pingfighter.runtime_skill_levels[victim_perk] = 1
    pingfighter._soldier_skill_unlocked[victim] = True
    pingfighter.soldier_weapon_unlocks[victim] = True

    controller = pingfighter.soldier_controller
    controller.reset()
    controller.permanent_owned.add(victim)
    controller.equipped_permanent.append(victim)
    controller.rebuild_inventory(set_active=victim)
    assert victim in controller.weapons

    removed = pingfighter._cleanup_heavenly_cape_overflow_skills()

    assert removed == [("soldier", victim)]
    assert victim not in pingfighter._soldier_equipped_skills
    assert victim_perk not in pingfighter.runtime_skill_levels
    assert not pingfighter._soldier_skill_unlocked[victim]
    assert not pingfighter.soldier_weapon_unlocks[victim]
    assert victim not in controller.permanent_owned
    assert victim not in controller.equipped_permanent
    assert victim not in controller.weapons


def test_soldier_academy_swap_failure_does_not_mutate_unlock_state(soldier_state_snapshot):
    new_perk = "soldier_unlock_bazooka"
    new_skill = "bazooka"
    pingfighter._soldier_equipped_skills = list(pingfighter.SOLDIER_BASE_SKILLS) + [
        "net_gun",
        "fire_support",
        "bowling_trap",
    ]
    pingfighter.runtime_skill_levels.pop(new_perk, None)
    pingfighter._soldier_skill_unlocked[new_skill] = False
    pingfighter.soldier_weapon_unlocks[new_skill] = False

    result = pingfighter.apply_academy_skill_swap("soldier", new_perk, "supply_drop")

    assert result is False
    assert new_skill not in pingfighter._soldier_equipped_skills
    assert new_perk not in pingfighter.runtime_skill_levels
    assert not pingfighter._soldier_skill_unlocked[new_skill]
    assert not pingfighter.soldier_weapon_unlocks[new_skill]
