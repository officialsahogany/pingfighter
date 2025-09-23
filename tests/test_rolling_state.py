import unittest

from core.legacy_state_accessor import bind_legacy_accessor
from core.player_state import RollingState


class RollingStateTests(unittest.TestCase):
    def test_defaults(self):
        store = {}
        rolling = RollingState(bind_legacy_accessor(store))
        self.assertFalse(rolling.active)
        self.assertEqual(rolling.charges, 1)
        self.assertEqual(rolling.token_states, [True])

    def test_setters_sync_store(self):
        store = {}
        rolling = RollingState(bind_legacy_accessor(store))
        rolling.active = True
        rolling.charges = 2
        rolling.token_states = [True, False]
        self.assertEqual(store["rolling_active"], True)
        self.assertEqual(store["rolling_charges"], 2)
        self.assertEqual(store["token_states"], [True, False])


if __name__ == "__main__":
    unittest.main()
