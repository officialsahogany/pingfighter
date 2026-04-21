import unittest

from core.boss_dash_token_display import get_boss_dash_token_display_state


class BossDashTokenDisplayTests(unittest.TestCase):
    def test_ready_state_shows_full_token(self):
        state = get_boss_dash_token_display_state(
            gauge=80,
            gauge_cost=50,
            cooldown_until_ms=0,
            cooldown_total_ms=0,
            now_ms=1000,
        )
        self.assertEqual(state["available"], 1)
        self.assertEqual(state["count_text"], "1/1")
        self.assertEqual(state["charge_progress"], 1.0)

    def test_cooldown_progress_is_visible_even_when_gauge_is_low(self):
        state = get_boss_dash_token_display_state(
            gauge=10,
            gauge_cost=50,
            cooldown_until_ms=2000,
            cooldown_total_ms=1000,
            now_ms=1500,
        )
        self.assertEqual(state["available"], 0)
        self.assertEqual(state["count_text"], "50%")
        self.assertAlmostEqual(state["charge_progress"], 0.5)

    def test_partial_gauge_shows_live_gauge_text(self):
        state = get_boss_dash_token_display_state(
            gauge=25,
            gauge_cost=50,
            cooldown_until_ms=0,
            cooldown_total_ms=0,
            now_ms=1000,
        )
        self.assertEqual(state["available"], 0)
        self.assertEqual(state["count_text"], "25/50")
        self.assertAlmostEqual(state["charge_progress"], 0.5)

    def test_dash_lock_keeps_token_unavailable(self):
        state = get_boss_dash_token_display_state(
            gauge=80,
            gauge_cost=50,
            cooldown_until_ms=0,
            cooldown_total_ms=0,
            now_ms=1000,
            is_dashing=True,
        )
        self.assertEqual(state["available"], 0)
        self.assertEqual(state["count_text"], "50/50")
        self.assertEqual(state["charge_progress"], 1.0)


if __name__ == "__main__":
    unittest.main()
