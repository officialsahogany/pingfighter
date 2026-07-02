extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetPerfProbe := preload("res://scripts/lingpet/lingpet_perf_probe.gd")

var _failures: Array[String] = []


class FakePerfLogger:
	extends RefCounted

	var begin_calls := 0
	var finished: Array[Dictionary] = []

	func begin_sample() -> int:
		begin_calls += 1
		return 4242

	func finish_sample(label: String, start_usec: int) -> void:
		finished.append({
			"label": label,
			"start_usec": start_usec,
		})


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	_verify_runtime_and_draw_logger_lookup()
	_verify_sample_begin_end_guards()
	_verify_runtime_delegates_perf_probe()

	if _failures.is_empty():
		print("lingpet_perf_probe_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_and_draw_logger_lookup() -> void:
	var probe := LingpetPerfProbe.new()
	var logger := FakePerfLogger.new()
	_expect(probe.get_runtime_logger(null) == null, "null registry should not expose a perf logger")
	_expect(probe.get_runtime_logger(FakeRegistry.new({"battle_perf_logger": "not an object"})) == null, "non-object runtime logger should be ignored")
	_expect(probe.get_runtime_logger(FakeRegistry.new({"battle_perf_logger": logger})) == logger, "registry battle_perf_logger should be returned")

	_expect(probe.get_draw_logger({}) == null, "missing draw perf logger should resolve null")
	_expect(probe.get_draw_logger({"battle_perf_logger": "not an object"}) == null, "non-object draw perf logger should be ignored")
	_expect(probe.get_draw_logger({"battle_perf_logger": logger}) == logger, "draw-context battle_perf_logger should be returned")


func _verify_sample_begin_end_guards() -> void:
	var probe := LingpetPerfProbe.new()
	var logger := FakePerfLogger.new()
	_expect_eq(probe.begin(null), 0, "null perf logger should begin at 0")
	_expect_eq(probe.begin(logger), 4242, "perf probe should forward begin_sample")
	probe.end(logger, "physics.lingpet.test", 4242)
	_expect_eq(logger.begin_calls, 1, "begin_sample should be called exactly once")
	_expect_eq(logger.finished.size(), 1, "finish_sample should be called once")
	if not logger.finished.is_empty():
		_expect_eq(str(logger.finished[0].get("label", "")), "physics.lingpet.test", "finish_sample should preserve the label")
		_expect_eq(int(logger.finished[0].get("start_usec", -1)), 4242, "finish_sample should preserve the start time")
	probe.end(null, "ignored", 1)
	_expect_eq(logger.finished.size(), 1, "null end should not add samples")


func _verify_runtime_delegates_perf_probe() -> void:
	var runtime := LingpetEggRuntime.new()
	_expect(runtime != null, "runtime fixture should construct")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var probe_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_perf_probe.gd")
	_expect(runtime_source.find("LingpetPerfProbe") >= 0, "egg runtime should preload the perf probe")
	_expect(runtime_source.find("_perf_probe.get_runtime_logger") >= 0, "runtime physics update should delegate logger lookup")
	_expect(runtime_source.find("_perf_probe.begin") >= 0, "runtime physics update should delegate sample begin")
	_expect(runtime_source.find("_perf_probe.end") >= 0, "runtime physics update should delegate sample end")
	_expect(runtime_source.find("_perf_probe.get_draw_logger") >= 0, "runtime draw should delegate draw-context logger lookup")
	_expect(runtime_source.find("func _get_perf_logger") < 0, "runtime should not keep a private perf logger getter")
	_expect(runtime_source.find("func _perf_begin") < 0, "runtime should not keep private perf begin")
	_expect(runtime_source.find("func _perf_end") < 0, "runtime should not keep private perf end")
	_expect(runtime_source.find("func _get_draw_perf_logger") < 0, "runtime should not keep private draw perf getter")
	_expect(probe_source.find("LOGGER_KEY") >= 0 and probe_source.find("battle_perf_logger") >= 0, "perf probe should own the BattlePerf registry key")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
