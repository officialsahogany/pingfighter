import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame
import items


def _make_item(name: str) -> dict:
    return {
        "x": 10,
        "y": 10,
        "vel": [0, 0],
        "type": {"name": name, "color": (0, 0, 0), "revealed": True},
        "timer": 0,
        "bounce_count": 0,
        "max_bounces": 0,
        "angle": 0,
    }


def _run_pickup(name: str):
    items.reset_items()
    items.item_list = [_make_item(name)]
    passive_calls = []
    active_calls = []

    def store_passive(item_data):
        passive_calls.append(item_data["name"])

    def store_active(item_data):
        active_calls.append(item_data["name"])

    player_rect = pygame.Rect(0, 0, 40, 40)
    items.update_items(
        player_rect,
        lambda *args, **kwargs: None,
        store_passive,
        store_active,
        sound_item_get=None,
    )
    return passive_calls, active_calls, items.item_list


def test_bulletproof_hat_routed_to_passive():
    pygame.init()
    passive, active, remaining = _run_pickup("bulletproof_hat")
    assert passive == ["bulletproof_hat"]
    assert active == []
    assert remaining == []


def test_spiked_helmet_routed_to_passive():
    pygame.init()
    passive, active, remaining = _run_pickup("spiked_helmet")
    assert passive == ["spiked_helmet"]
    assert active == []
    assert remaining == []
