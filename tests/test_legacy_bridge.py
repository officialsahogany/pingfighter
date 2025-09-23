import types
import unittest

from game_logic.legacy_state_bridge import (
    LEGACY_STATE_KEYS,
    PLAYER_KEYS,
    legacy_ball_sync,
    legacy_player_sync,
    legacy_sync,
    prime_store_from_namespace,
    sync_namespace_to_state,
    sync_state_to_namespace,
)


class DummyState:
    def __init__(self):
        self.legacy_globals = {}
        self._legacy_bridge_primed = False


class LegacyBridgeTests(unittest.TestCase):
    def setUp(self):
        self.state = DummyState()
        self.namespace = types.SimpleNamespace()

    def test_prime_store_from_namespace(self):
        sample_key = next(iter(LEGACY_STATE_KEYS))
        setattr(self.namespace, sample_key, 42)
        prime_store_from_namespace(self.state, self.namespace)
        self.assertIn(sample_key, self.state.legacy_globals)
        self.assertEqual(self.state.legacy_globals[sample_key], 42)

    def test_sync_state_to_namespace_roundtrip(self):
        keys = list(PLAYER_KEYS)[:5]
        for index, key in enumerate(keys):
            self.state.legacy_globals[key] = index
        sync_state_to_namespace(self.state, self.namespace, keys)
        for index, key in enumerate(keys):
            self.assertEqual(getattr(self.namespace, key), index)
            setattr(self.namespace, key, index + 10)
        sync_namespace_to_state(self.state, self.namespace, keys)
        for index, key in enumerate(keys):
            self.assertEqual(self.state.legacy_globals[key], index + 10)

    def test_legacy_context_manager_updates_store(self):
        keys = list(PLAYER_KEYS)[:3]
        for key in keys:
            self.state.legacy_globals[key] = 0
        with legacy_sync(self.state, self.namespace, keys):
            for idx, key in enumerate(keys):
                setattr(self.namespace, key, idx * 5)
        for idx, key in enumerate(keys):
            self.assertEqual(self.state.legacy_globals[key], idx * 5)

    def test_specialized_context_scopes(self):
        key = next(iter(PLAYER_KEYS))
        self.state.legacy_globals[key] = 1
        with legacy_player_sync(self.state, self.namespace):
            setattr(self.namespace, key, 7)
        self.assertEqual(self.state.legacy_globals[key], 7)
        with legacy_ball_sync(self.state, self.namespace):
            setattr(self.namespace, key, 99)
        self.assertEqual(self.state.legacy_globals[key], 7)


if __name__ == "__main__":
    unittest.main()
