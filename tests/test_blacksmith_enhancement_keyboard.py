import os
import sys
import types

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame
import pytest

from downtown.building_interior import BuildingInterior
from downtown.constants import BuildingType


@pytest.fixture(scope="module", autouse=True)
def init_pygame():
    pygame.init()
    yield
    pygame.quit()


def _make_item(name: str) -> dict:
    return {
        "name": name,
        "rolled_options": [{"key": "power", "value": 1}],
        "enhancement_level": 0,
    }


def test_blacksmith_enhancement_menu_keyboard_opens_item_select(monkeypatch):
    fake_pingfighter = types.SimpleNamespace(passive_item_list=[])
    monkeypatch.setitem(sys.modules, "pingfighter", fake_pingfighter)

    interior = BuildingInterior(BuildingType.BLACKSMITH, {})
    interior.enhancement_menu_open = True
    interior.enhancement_menu_selection = 0

    result = interior.handle_key(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_RETURN))

    assert result == ("enhancement_item_select", None)
    assert interior.enhancement_menu_open is False
    assert interior.enhancement_item_select_open is True
    assert interior.enhancement_focus_index == -1


def test_blacksmith_enhancement_item_select_keyboard_moves_and_confirms(monkeypatch):
    items = [_make_item(f"item_{idx}") for idx in range(8)]
    fake_pingfighter = types.SimpleNamespace(passive_item_list=items)
    monkeypatch.setitem(sys.modules, "pingfighter", fake_pingfighter)

    interior = BuildingInterior(BuildingType.BLACKSMITH, {})
    interior._open_enhancement_item_select()

    move_right = interior.handle_key(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_RIGHT))
    move_down = interior.handle_key(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_DOWN))
    confirm = interior.handle_key(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_RETURN))

    assert move_right == ("enhancement_item_move", 1)
    assert move_down == ("enhancement_item_move", 7)
    assert confirm[0] == "enhancement_confirm"
    assert interior.enhancement_focus_index == 7
    assert interior.enhancement_selected_idx == 7
    assert interior.enhancement_selected_item["name"] == "item_7"
    assert interior.enhancement_item_select_open is False
    assert interior.enhancement_confirm_open is True
