import unittest
from unittest.mock import MagicMock, patch

import pygame

from supply_drop import SupplyDropRuntime, update_system


class DummyAircraft:
    def __init__(self) -> None:
        self.active = True

    def update(self) -> None:
        pass

    def check_ball_collision(self, *_args, **_kwargs) -> bool:  # noqa: D401 - simple stub
        return False

    def check_paddle_brick_collision(self, *_args, **_kwargs) -> None:  # noqa: D401 - simple stub
        pass

    def stop_sound(self) -> None:
        pass


class SupplyDropRuntimeTest(unittest.TestCase):
    def test_radio_loop_start_stop(self) -> None:
        runtime = SupplyDropRuntime()

        with patch("pygame.mixer.Sound") as sound_cls:
            fake_sound = MagicMock()
            fake_channel = MagicMock()
            fake_sound.play.return_value = fake_channel
            sound_cls.return_value = fake_sound

            runtime.start_radio_loop(lambda path: path)

            self.assertTrue(runtime.state.radio_motion)
            self.assertTrue(runtime.hold_active)
            self.assertGreaterEqual(runtime.state.radio_timer, 30)

            runtime.stop_radio_loop()

            self.assertFalse(runtime.state.radio_motion)
            self.assertEqual(runtime.state.radio_timer, 0)
            self.assertFalse(runtime.hold_active)
            fake_channel.stop.assert_not_called()

            runtime.stop_radio_loop(force=True)
            fake_channel.stop.assert_called()

    def test_update_system_spawns_and_clears_aircraft(self) -> None:
        runtime = SupplyDropRuntime()
        runtime.state.active = True
        runtime.state.timer = 1

        created = {}

        def factory(direction: str) -> DummyAircraft:
            created["direction"] = direction
            return DummyAircraft()

        update_system(
            runtime,
            width=800,
            height=600,
            ball_rect=pygame.Rect(0, 0, 10, 10),
            last_hit_by="player",
            ball_velocity=[0, 1],
            player_rect=pygame.Rect(0, 0, 50, 50),
            boss_rect=pygame.Rect(0, 0, 50, 50),
            bricks=[],
            activate_item=lambda name: None,
            create_aircraft=factory,
        )

        self.assertIn("direction", created)
        self.assertIsNotNone(runtime.state.aircraft)

        # Simulate the aircraft finishing its sequence
        runtime.state.aircraft.active = False  # type: ignore[union-attr]
        update_system(
            runtime,
            width=800,
            height=600,
            ball_rect=pygame.Rect(0, 0, 10, 10),
            last_hit_by="player",
            ball_velocity=[0, 1],
            player_rect=pygame.Rect(0, 0, 50, 50),
            boss_rect=pygame.Rect(0, 0, 50, 50),
            bricks=[],
            activate_item=lambda name: None,
            create_aircraft=factory,
        )

        self.assertFalse(runtime.state.active)
        self.assertIsNone(runtime.state.aircraft)


if __name__ == "__main__":  # pragma: no cover - manual execution helper
    unittest.main()
