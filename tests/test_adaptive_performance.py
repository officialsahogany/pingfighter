from core.adaptive_performance import (
    AdaptivePerformanceController,
    LEVEL_CRITICAL,
    LEVEL_NORMAL,
    LEVEL_WARNING,
)


def test_controller_stays_normal_under_target_frame_time():
    controller = AdaptivePerformanceController(target_fps=60)

    for _ in range(90):
        snapshot = controller.update(16.0)

    assert snapshot.level == LEVEL_NORMAL
    assert snapshot.average_fps > 55.0


def test_controller_escalates_after_sustained_frame_drop():
    controller = AdaptivePerformanceController(target_fps=60)

    for _ in range(90):
        snapshot = controller.update(28.0)

    assert snapshot.level in {LEVEL_WARNING, LEVEL_CRITICAL}
    assert snapshot.average_fps < 45.0


def test_controller_recovers_after_stable_frames():
    controller = AdaptivePerformanceController(target_fps=60)

    for _ in range(90):
        controller.update(30.0)

    assert controller.level == LEVEL_CRITICAL

    for _ in range(40):
        controller.update(16.0)

    assert controller.level in {LEVEL_NORMAL, LEVEL_WARNING}

    for _ in range(40):
        controller.update(16.0)

    assert controller.level == LEVEL_NORMAL


def test_disabling_controller_clears_stress_level():
    controller = AdaptivePerformanceController(target_fps=60)

    for _ in range(60):
        controller.update(35.0)

    assert controller.level == LEVEL_CRITICAL

    controller.set_enabled(False)
    snapshot = controller.update(16.0)

    assert snapshot.level == LEVEL_NORMAL
    assert controller.stress_score == 0.0
