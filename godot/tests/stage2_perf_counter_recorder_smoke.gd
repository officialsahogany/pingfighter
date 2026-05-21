extends SceneTree

const Stage2PerfCounterRecorder := preload("res://scripts/stages/stage2/stage2_perf_counter_recorder.gd")

var _failures: Array[String] = []


class FakeCounterLogger:
	extends RefCounted

	var samples := {}

	func record_counter_sample(label: String, value: Variant) -> void:
		samples[label] = value


func _init() -> void:
	_verify_overlay_counters()
	_verify_obstacle_counters()
	_verify_missing_logger_is_safe()

	if _failures.is_empty():
		print("stage2_perf_counter_recorder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_overlay_counters() -> void:
	var logger := FakeCounterLogger.new()
	Stage2PerfCounterRecorder.record_playfield_overlay_counters(
		logger,
		4,
		5,
		6,
		true,
		false,
		true,
		false
	)
	_expect(int(logger.samples.get("stage2.overlay.leaf_particles", -1)) == 4, "overlay counters should record leaf particles")
	_expect(int(logger.samples.get("stage2.overlay.starpoint_particles", -1)) == 5, "overlay counters should record starpoint particles")
	_expect(int(logger.samples.get("stage2.overlay.starpoint_drops", -1)) == 6, "overlay counters should record starpoint drops")
	_expect(int(logger.samples.get("stage2.overlay.border_flash_active", -1)) == 1, "overlay counters should expose border-flash activity")
	_expect(int(logger.samples.get("stage2.overlay.rage_tint_active", -1)) == 0, "overlay counters should expose inactive rage tint")
	_expect(int(logger.samples.get("stage2.overlay.fragment_flash_active", -1)) == 1, "overlay counters should expose fragment flash activity")
	_expect(int(logger.samples.get("stage2.overlay.skill_warning_active", -1)) == 0, "overlay counters should expose inactive skill warning")


func _verify_obstacle_counters() -> void:
	var logger := FakeCounterLogger.new()
	Stage2PerfCounterRecorder.record_playfield_obstacle_counters(
		logger,
		7,
		8,
		9,
		true,
		false,
		10
	)
	_expect(int(logger.samples.get("stage2.obstacles.rocks", -1)) == 7, "obstacle counters should record rocks")
	_expect(int(logger.samples.get("stage2.obstacles.rock_fragments", -1)) == 8, "obstacle counters should record rock fragments")
	_expect(int(logger.samples.get("stage2.obstacles.water_splashes", -1)) == 9, "obstacle counters should record water splashes")
	_expect(int(logger.samples.get("stage2.obstacles.quake_active", -1)) == 1, "obstacle counters should expose quake activity")
	_expect(int(logger.samples.get("stage2.obstacles.water_cannon_active", -1)) == 0, "obstacle counters should expose inactive water cannon")
	_expect(int(logger.samples.get("stage2.obstacles.water_trail", -1)) == 10, "obstacle counters should record water trail count")


func _verify_missing_logger_is_safe() -> void:
	Stage2PerfCounterRecorder.record_playfield_overlay_counters(null, 1, 1, 1, true, true, true, true)
	Stage2PerfCounterRecorder.record_playfield_obstacle_counters(RefCounted.new(), 1, 1, 1, true, true, 1)
	_expect(true, "missing or incompatible loggers should be ignored")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
