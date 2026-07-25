extends SceneTree

const GapClassifier := preload("res://scripts/core/battle_perf_gap_classifier.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_baseline_and_render_classes()
	_verify_process_monitor_classes()
	_verify_physics_monitor_and_cadence_classes()
	if _failures.is_empty():
		print("battle_perf_gap_classifier_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_baseline_and_render_classes() -> void:
	_expect(GapClassifier.classify({}, 0.0) == "baseline-gap", "empty metrics should classify as a baseline gap")
	var classification := GapClassifier.classify({
		"draw_shell_ms": 11.0,
		"draw_calls": 900,
		"primitives": 40000,
	}, 31.0)
	_expect(classification.find("frame-pacing") >= 0, "large local frame delta should classify frame pacing")
	_expect(classification.find("render-heavy") >= 0, "heavy draw metrics should classify render load")
	classification = GapClassifier.classify({
		"process_ms": 14.0,
		"proc_gap_ms": 9.0,
		"proc_after_draw_ms": 7.0,
		"proc_shell_max_ms": 4.0,
		"draw_shell_max_ms": 3.0,
	}, 14.0)
	_expect(classification.find("engine-process") >= 0, "accounted local metrics should expose engine process overhead")


func _verify_process_monitor_classes() -> void:
	var stale_metrics := {
		"process_ms": 77.0,
		"proc_gap_ms": 76.0,
		"proc_after_draw_ms": 71.0,
		"frame_idle_ms": -65.0,
		"proc_shell_max_ms": 25.9,
		"draw_shell_max_ms": 26.8,
	}
	_expect(GapClassifier.is_process_monitor_lag(stale_metrics, 77.5), "large negative idle should flag a stale process monitor")
	var classification := GapClassifier.classify(stale_metrics, 77.5)
	_expect(classification.find("monitor-process-lag") >= 0, "stale process metrics should use the monitor-lag class")
	_expect(classification.find("engine-process") < 0, "stale process metrics should not claim real engine process cost")


func _verify_physics_monitor_and_cadence_classes() -> void:
	_expect(GapClassifier.is_physics_cadence_gap(53, 45, 98), "draw-to-physics sample ratio should detect cadence gaps")
	_expect(not GapClassifier.is_physics_cadence_gap(60, 60, 60), "matching sample counts should not detect cadence gaps")
	var stale_physics := {
		"physics_ms": 22.8,
		"phys_gap_ms": 19.8,
		"phys_shell_ms": 3.1,
		"phys_shell_max_ms": 5.1,
		"proc_shell_count": 14,
		"phys_shell_count": 47,
		"draw_shell_count": 56,
		"physics_2d_active": 0,
		"physics_2d_pairs": 0,
		"physics_2d_islands": 0,
	}
	_expect(GapClassifier.is_physics_monitor_lag(stale_physics), "empty 2D counters should identify stale physics monitor cost")
	var classification := GapClassifier.classify(stale_physics, 10.0)
	_expect(classification.find("monitor-physics-lag") >= 0, "stale physics metrics should use the monitor-lag class")
	_expect(classification.find("engine-physics") < 0, "stale physics metrics should not claim real engine physics cost")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
