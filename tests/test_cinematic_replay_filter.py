import unittest
from unittest import mock

from cinematic import _REPLAY_SCREENSAVER_MAX_BYTES, _filter_idle_replay_candidates


class CinematicReplayFilterTest(unittest.TestCase):
    def test_filter_skips_oversized_and_missing_files(self):
        replays = [
            {"filepath": "small.rpl", "filename": "small.rpl"},
            {"filepath": "big.rpl", "filename": "big.rpl"},
            {"filepath": "missing.rpl", "filename": "missing.rpl"},
            {"filename": "no_path.rpl"},
        ]

        def fake_getsize(path):
            if path == "small.rpl":
                return 32
            if path == "big.rpl":
                return _REPLAY_SCREENSAVER_MAX_BYTES + 1
            raise OSError("missing")

        with mock.patch("cinematic.os.path.getsize", side_effect=fake_getsize):
            filtered = _filter_idle_replay_candidates(replays)

        self.assertEqual(filtered, [{"filepath": "small.rpl", "filename": "small.rpl"}])


if __name__ == "__main__":
    unittest.main()
