import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
os.environ.setdefault("PINGFIGHTER_SMOKE_TEST", "1")

import pygame

import pingfighter


def _build_snapshot():
    return {
        "turret_x": 320,
        "divine_x": 480,
        "turret": {
            "rect": pygame.Rect(300, 640, 40, 55),
            "hp": 8,
            "max_hp": 10,
            "level": 2,
            "xp": 42.5,
        },
        "divine": {
            "rect": pygame.Rect(450, 610, 36, 72),
            "hp": 25,
            "max_hp": 30,
            "shield_ripple_effects": [{"progress": 0.25}],
            "_shield_work": pygame.Surface((8, 8), pygame.SRCALPHA),
        },
    }


def test_blacksmith_persist_snapshot_serialization_round_trip():
    snapshot = _build_snapshot()

    serialized = pingfighter._serialize_blacksmith_persist_for_save(snapshot)

    assert serialized is not None
    assert serialized["turret"]["rect"]["__type__"] == "pygame.Rect"
    assert "_shield_work" not in serialized["divine"]

    restored = pingfighter._deserialize_blacksmith_persist_from_save(serialized)

    assert isinstance(restored["turret"]["rect"], pygame.Rect)
    assert restored["turret"]["rect"].size == (40, 55)
    assert restored["divine"]["rect"].midbottom == snapshot["divine"]["rect"].midbottom
    assert restored["divine"]["shield_ripple_effects"] == [{"progress": 0.25}]


def test_apply_loaded_progress_restores_blacksmith_persist_snapshot():
    serialized = pingfighter._serialize_blacksmith_persist_for_save(_build_snapshot())
    pingfighter.blacksmith_persist_structures = None

    assert pingfighter.apply_loaded_progress(
        {
            "stage_number": 2,
            "character_type": "blacksmith",
            "blacksmith_persist_structures": serialized,
        }
    )

    restored = pingfighter.blacksmith_persist_structures
    assert restored is not None
    assert isinstance(restored["divine"]["rect"], pygame.Rect)
    assert restored["turret_x"] == 320
