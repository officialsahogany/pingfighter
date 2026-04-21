import json
import os
from types import SimpleNamespace

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
os.environ.setdefault("PINGFIGHTER_SMOKE_TEST", "1")

import pingfighter
from soldier.controller import SoldierWeaponController


def test_start_game_with_difficulty_clears_stale_runtime_items(monkeypatch, tmp_path):
    save_path = tmp_path / pingfighter.GAME_SAVE_FILE
    save_path.write_text(json.dumps({"stage_number": 3}), encoding="utf-8")

    pingfighter.active_item_slot[:] = [{"name": "grenade"}]
    pingfighter.passive_item_list[:] = [{"name": "battery", "_equipped_slot": "body"}]
    pingfighter.selected_item_index = 2
    pingfighter.MAX_ITEM_SLOTS = 5
    pingfighter.last_item_use_time = 777
    pingfighter._pending_ammo_restore = {"bazooka": {"ammo_count": 1}}
    pingfighter._pending_weapon_degradation = {"degraded": ["ak47"]}

    monkeypatch.setattr(pingfighter, "_get_save_directory", lambda: str(tmp_path))
    monkeypatch.setattr(pingfighter, "main", lambda stage_num: None)
    monkeypatch.setattr(pingfighter, "reset_runtime_skill_system", lambda: None)
    monkeypatch.setattr(pingfighter, "apply_player_paddle_scale", lambda mode: None)
    monkeypatch.setattr(pingfighter, "clear_paddle_cache", lambda: None)
    monkeypatch.setattr(pingfighter, "apply_equipment_paddle_modifiers", lambda: None)
    monkeypatch.setattr(pingfighter, "align_player_to_floor", lambda: None)
    monkeypatch.setattr(pingfighter, "sync_equipped_passive_effects", lambda: None)

    soldier_controller = SoldierWeaponController()
    soldier_controller.add_weapon("rocket_launcher")
    soldier_controller.current_index = 1
    soldier_controller.switch_cooldown = 99
    soldier_controller.reload_counts["rocket_launcher"] = 2
    soldier_controller.degradation_thresholds["rocket_launcher"] = 10
    soldier_controller.degraded.add("rocket_launcher")
    soldier_controller.ui_highlight_timer = 42
    monkeypatch.setattr(pingfighter, "soldier_controller", soldier_controller)

    bazooka = SimpleNamespace(ammo_count=0, max_ammo=6)
    ak47 = SimpleNamespace(current_ammo=0, max_ammo=30, remaining_time=0, duration=15)
    net_gun = SimpleNamespace(ammo_count=0, MAX_AMMO=4)
    fire_support = SimpleNamespace(ammo_count=0, max_ammo=2)
    bowling_trap = SimpleNamespace(ammo_count=0, max_ammo=3)
    monkeypatch.setattr(pingfighter, "get_bazooka_instance", lambda: bazooka, raising=False)
    monkeypatch.setattr(pingfighter, "get_ak47_instance", lambda: ak47, raising=False)
    monkeypatch.setattr(pingfighter, "get_net_gun_instance", lambda: net_gun, raising=False)
    monkeypatch.setattr(pingfighter, "get_fire_support_instance", lambda: fire_support, raising=False)
    monkeypatch.setattr(pingfighter, "get_bowling_trap_instance", lambda: bowling_trap, raising=False)

    pingfighter.start_game_with_difficulty("normal", "junior")

    assert pingfighter.active_item_slot == []
    assert pingfighter.passive_item_list == []
    assert pingfighter.selected_item_index == 0
    assert pingfighter.MAX_ITEM_SLOTS == 3
    assert pingfighter.last_item_use_time == 0
    assert pingfighter._pending_ammo_restore == {}
    assert pingfighter._pending_weapon_degradation == {}
    assert not save_path.exists()


def test_reset_full_run_state_clears_additional_run_state(monkeypatch, tmp_path):
    save_path = tmp_path / pingfighter.GAME_SAVE_FILE
    save_path.write_text(json.dumps({"stage_number": 4}), encoding="utf-8")

    pingfighter.runtime_skill_levels = {"common_bulk_up": 3}
    pingfighter.starpoint_for_skills = 7
    pingfighter.pending_skill_choices = 2
    pingfighter.runtime_accessory_slot_bonus = 2
    pingfighter.runtime_swiftness_bonus = 1
    pingfighter.transcendent_crown_skill_bonus = 5
    pingfighter.stage_clear_choices_active = True
    pingfighter.stage_clear_choices_shown = True
    pingfighter.stage_clear_choices_list = [{"id": "bulk_up"}]
    first_optimus_key = next(iter(pingfighter.optimus_skill_levels))
    pingfighter.optimus_skill_levels[first_optimus_key] = 4
    pingfighter.emergency_charge_used_this_stage = True
    pingfighter.arena_perk_speed_mult_bottom = 1.75
    pingfighter.arena_perk_guard_extra_skill_top = True
    pingfighter.arena_active_hero_perks = ["guard_focus"]
    pingfighter.arena_active_enemy_perks = ["storm_rush"]
    pingfighter.special_gauge = 123
    pingfighter.displayed_gauge = 120

    calls = []
    fake_legendary = SimpleNamespace(
        reset_for_new_game=lambda: calls.append("legendary_reset")
    )

    monkeypatch.setattr(pingfighter, "_get_save_directory", lambda: str(tmp_path))
    monkeypatch.setattr(
        pingfighter.academy,
        "reset_all_skills",
        lambda: calls.append("academy_reset_all"),
    )
    monkeypatch.setattr(
        pingfighter.academy,
        "reset_skill_points",
        lambda: calls.append("academy_reset_points"),
    )
    monkeypatch.setattr(
        pingfighter,
        "reset_cleanse_skill",
        lambda: calls.append("cleanse_reset"),
    )
    monkeypatch.setattr(
        pingfighter,
        "get_legendary_manager",
        lambda: fake_legendary,
    )

    pingfighter.reset_full_run_state(delete_save=True)

    assert not save_path.exists()
    assert pingfighter.runtime_skill_levels == {}
    assert pingfighter.starpoint_for_skills == 0
    assert pingfighter.pending_skill_choices == 0
    assert pingfighter.runtime_accessory_slot_bonus == 0
    assert pingfighter.runtime_swiftness_bonus == 0
    assert pingfighter.transcendent_crown_skill_bonus == 0
    assert pingfighter.stage_clear_choices_active is False
    assert pingfighter.stage_clear_choices_shown is False
    assert pingfighter.stage_clear_choices_list == []
    assert pingfighter.optimus_skill_levels[first_optimus_key] == 0
    assert pingfighter.emergency_charge_used_this_stage is False
    assert pingfighter.arena_perk_speed_mult_bottom == 1.0
    assert pingfighter.arena_perk_guard_extra_skill_top is False
    assert pingfighter.arena_active_hero_perks == []
    assert pingfighter.arena_active_enemy_perks == []
    assert pingfighter.special_gauge == 0
    assert pingfighter.displayed_gauge == 0
    assert "academy_reset_all" in calls
    assert "academy_reset_points" in calls
    assert "cleanse_reset" in calls
    assert "legendary_reset" in calls


def test_start_ai_play_from_menu_uses_standard_new_game_path(monkeypatch):
    recorded = {}

    def fake_start_game(character_id, difficulty_mode, *, auto_play=False):
        recorded["call"] = (character_id, difficulty_mode, auto_play)

    monkeypatch.setattr(pingfighter, "ai_mode", "champion")
    monkeypatch.setattr(pingfighter, "start_game_with_difficulty", fake_start_game)

    pingfighter.start_ai_play_from_menu("soldier")

    assert recorded["call"] == ("soldier", "champion", True)
