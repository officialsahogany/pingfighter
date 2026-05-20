extends RefCounted

const PERF_LOG_ENV := "PINGFIGHTER_STAGE2_PERF_LOG"
const PERF_LOG_FLAG_PATH := "res://stage2_perf_log.flag"
const PERF_LOG_INTERVAL_SEC := 0.75

var log_checked := false
var log_enabled := false
var next_log_msec := 0
var samples := {}


func begin_sample() -> int:
	if not _is_enabled():
		return 0
	return Time.get_ticks_usec()


func finish_sample(label: String, start_usec: int) -> void:
	if start_usec <= 0:
		return
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var sample: Dictionary = samples.get(label, {"count": 0, "total": 0.0, "max": 0.0})
	sample["count"] = int(sample.get("count", 0)) + 1
	sample["total"] = float(sample.get("total", 0.0)) + elapsed_ms
	sample["max"] = max(float(sample.get("max", 0.0)), elapsed_ms)
	samples[label] = sample


func maybe_log(state: Dictionary) -> void:
	if not _is_enabled() or samples.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < next_log_msec:
		return
	next_log_msec = now_msec + int(PERF_LOG_INTERVAL_SEC * 1000.0)
	print(
		"[Stage2Perf] stage=",
		int(state.get("stage", 1)),
		" rocks=",
		int(state.get("rocks", 0)),
		" rock_fragments=",
		int(state.get("rock_fragments", 0)),
		" water_splashes=",
		int(state.get("water_splashes", 0)),
		" water_trail=",
		int(state.get("water_trail", 0)),
		" quake=%.2f" % float(state.get("quake_timer", 0.0)),
		" rage=",
		bool(state.get("boss_rage_active", false)),
		" water_phase=",
		str(state.get("water_cannon_phase", "")),
		" warning=",
		str(state.get("skill_warning_kind", "")),
		" | ",
		_build_sample_summary()
	)
	samples.clear()


func _build_sample_summary() -> String:
	var keys := samples.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var sample: Dictionary = samples.get(key, {})
		var count: int = max(1, int(sample.get("count", 0)))
		var average_ms: float = float(sample.get("total", 0.0)) / float(count)
		parts.append("%s avg=%.3fms max=%.3fms n=%d" % [
			str(key),
			average_ms,
			float(sample.get("max", 0.0)),
			count,
		])
	var joined := ""
	for idx in range(parts.size()):
		if idx > 0:
			joined += "; "
		joined += parts[idx]
	return joined


func _is_enabled() -> bool:
	if log_checked:
		return log_enabled
	log_checked = true
	var value := OS.get_environment(PERF_LOG_ENV).strip_edges().to_lower()
	log_enabled = value in ["1", "true", "yes", "on"] or FileAccess.file_exists(PERF_LOG_FLAG_PATH)
	return log_enabled
