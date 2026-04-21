import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
os.environ.setdefault("PINGFIGHTER_SMOKE_TEST", "1")

import pingfighter


def test_dark_blade_autofire_only_opens_inside_time_window():
    near_ball_y = 350.0
    player_y = 420.0

    assert not pingfighter._should_viper_force_dark_blade_autofire(
        pingfighter._VIPER_DARK_BLADE_AUTO_FIRE_START_MS - 1,
        ball_velocity_y=8.0,
        ball_centery=near_ball_y,
        player_centery=player_y,
    )

    assert pingfighter._should_viper_force_dark_blade_autofire(
        pingfighter._VIPER_DARK_BLADE_AUTO_FIRE_START_MS,
        ball_velocity_y=8.0,
        ball_centery=near_ball_y,
        player_centery=player_y,
    )

    assert pingfighter._should_viper_force_dark_blade_autofire(
        pingfighter._VIPER_DARK_BLADE_AUTO_FIRE_END_MS,
        ball_velocity_y=8.0,
        ball_centery=near_ball_y,
        player_centery=player_y,
    )

    assert not pingfighter._should_viper_force_dark_blade_autofire(
        pingfighter._VIPER_DARK_BLADE_AUTO_FIRE_END_MS + 1,
        ball_velocity_y=8.0,
        ball_centery=near_ball_y,
        player_centery=player_y,
    )


def test_dark_blade_autofire_requires_descending_near_ball():
    elapsed_ms = pingfighter._VIPER_DARK_BLADE_AUTO_FIRE_START_MS

    assert not pingfighter._should_viper_force_dark_blade_autofire(
        elapsed_ms,
        ball_velocity_y=-4.0,
        ball_centery=360.0,
        player_centery=420.0,
    )

    assert not pingfighter._should_viper_force_dark_blade_autofire(
        elapsed_ms,
        ball_velocity_y=10.0,
        ball_centery=200.0,
        player_centery=420.0,
    )
