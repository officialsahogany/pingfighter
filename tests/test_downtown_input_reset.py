"""downtown 입력 상태 리셋 검증 테스트."""

import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402  (env 세팅 이후 import)
import pytest

from downtown.player import DowntownPlayer
from downtown.building_interior import InteriorPlayer


@pytest.fixture(scope="module", autouse=True)
def init_pygame():
    pygame.init()
    yield
    pygame.quit()


def test_downtown_player_reset_input_state():
    player = DowntownPlayer(100, 100)
    player.handle_movement_key_event(True, keycode=pygame.K_a)
    player.velocity_x = -player.speed
    player.velocity_y = player.speed
    player.is_moving = True

    player.reset_input_state()

    assert not player.pressed_keys
    assert not player._scancode_map
    assert player.velocity_x == 0
    assert player.velocity_y == 0
    assert player.is_moving is False


def test_interior_player_reset_input_state():
    player = InteriorPlayer(50, 50)
    player.handle_movement_key_event(True, keycode=pygame.K_d)
    player.velocity_x = player.speed
    player.velocity_y = -player.speed
    player.is_moving = True

    player.reset_input_state()

    assert not player.pressed_keys
    assert not player._scancode_map
    assert player.velocity_x == 0
    assert player.velocity_y == 0
    assert player.is_moving is False
