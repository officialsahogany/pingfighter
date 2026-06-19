extends RefCounted

const PERF_LOG_ENV := "PINGFIGHTER_BATTLE_PERF_LOG"
const PERF_DETAIL_ENV := "PINGFIGHTER_BATTLE_PERF_DETAIL"
const PERF_SAMPLES_ENV := "PINGFIGHTER_BATTLE_PERF_SAMPLES"
const PERF_LOG_INTERVAL_ENV := "PINGFIGHTER_BATTLE_PERF_INTERVAL_SEC"
const PERF_GAP_THRESHOLD_ENV := "PINGFIGHTER_BATTLE_PERF_GAP_MSEC"
const PERF_SPIKE_THRESHOLD_ENV := "PINGFIGHTER_BATTLE_PERF_SPIKE_USEC"
const PERF_LOG_FLAG_PATH := "res://battle_perf_log.flag"
const PERF_DETAIL_FLAG_PATH := "res://battle_perf_detail.flag"
const PERF_SAMPLES_FLAG_PATH := "res://battle_perf_samples.flag"
const DEFAULT_LOG_INTERVAL_SEC := 2.0
const DEFAULT_SPIKE_THRESHOLD_USEC := 8000
const DEFAULT_GAP_THRESHOLD_MSEC := 8.0
const GAP_HOT_SAMPLE_LIMIT := 8
const GAP_HOT_SAMPLE_AVG_MSEC := 0.75
const GAP_HOT_SAMPLE_MAX_MSEC := 4.0
const GAP_STAGE_HOT_SAMPLE_LIMIT := 10
const GAP_STAGE_HOT_PREFIXES := [
	"draw.frame.pillar_overlay",
	"draw.pillar_overlay.",
	"stage1.pillar_ui.",
	"stage2.",
	"stage3.",
	"stage5.",
	"physics.stage5.hongryun.",
]
const GAP_PLAYFIELD_HOT_SAMPLE_LIMIT := 8
const GAP_PLAYFIELD_HOT_PREFIXES := [
	"actors.",
	"context.",
	"draw.ball_effects.",
	"ball.visual.",
	"ball.status_overlay",
	"active_item.",
	"mythic.",
	"viper.skill.",
]
const GAP_FRAME_PACING_DELTA_MSEC := 30.0
const GAP_RENDER_HEAVY_DRAW_MSEC := 10.0
const GAP_RENDER_HEAVY_CALLS := 800
const GAP_RENDER_HEAVY_PRIMITIVES := 32000
const GAP_ENGINE_PROCESS_MSEC := 5.0
const GAP_ENGINE_PHYSICS_MSEC := 8.0
const GAP_MONITOR_STALE_MARGIN_MSEC := 8.0
const GAP_SUMMARY_VERSION := 2
const SPIKE_DETAIL_DELTA_TRIGGER_MSEC := 40.0
const SPIKE_DETAIL_PHYS_TRIGGER_MSEC := 8.0
const SPIKE_DETAIL_DRAW_TRIGGER_MSEC := 16.0
const SPIKE_DETAIL_LIMIT := 24
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const BattlePerfProcessNodeReporter := preload("res://scripts/core/battle_perf_process_node_reporter.gd")
const BattlePerfSpikeWindowReporter := preload("res://scripts/core/battle_perf_spike_window_reporter.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")

var log_checked := false
var log_enabled := false
var detail_checked := false
var detail_enabled := false
var sample_summary_checked := false
var sample_summary_enabled := false
var log_interval_checked := false
var log_interval_sec := DEFAULT_LOG_INTERVAL_SEC
var spike_threshold_checked := false
var spike_threshold_usec := DEFAULT_SPIKE_THRESHOLD_USEC
var gap_threshold_checked := false
var gap_threshold_msec := DEFAULT_GAP_THRESHOLD_MSEC
var next_log_msec := 0
var samples := {}
var counters := {}
var scene_owner: Node = null
var last_context: Dictionary = {}
var jetpack_state_counts: Dictionary = {"thrust": 0, "glide": 0, "ground": 0}
var air_strike_event_counts: Dictionary = {"hits": 0, "post_hit_frames": 0}
var _previous_air_strike_flash_timer: float = 0.0
var process_node_reporter: Object = BattlePerfProcessNodeReporter.new()
var spike_window_reporter: Object = BattlePerfSpikeWindowReporter.new()


func set_scene_owner(owner: Node) -> void:
	scene_owner = owner


func remember_context(context: Dictionary = {}) -> void:
	if context.is_empty():
		return
	last_context = context.duplicate(true)
	_accumulate_jetpack_state(context)


func _accumulate_jetpack_state(context: Dictionary) -> void:
	if str(context.get("selected_character_type", "")) != "viper":
		_previous_air_strike_flash_timer = 0.0
		return
	var key: String
	if bool(context.get("viper_jetpack_active", false)):
		key = "thrust"
	elif bool(context.get("viper_jetpack_airborne", false)):
		key = "glide"
	else:
		key = "ground"
	jetpack_state_counts[key] = int(jetpack_state_counts.get(key, 0)) + 1
	var current_timer: float = float(context.get("viper_air_strike_flash_timer", 0.0))
	if current_timer > 0.0:
		air_strike_event_counts["post_hit_frames"] = int(air_strike_event_counts.get("post_hit_frames", 0)) + 1
		if _previous_air_strike_flash_timer <= 0.0:
			air_strike_event_counts["hits"] = int(air_strike_event_counts.get("hits", 0)) + 1
	_previous_air_strike_flash_timer = current_timer


func _build_jetpack_label() -> String:
	var thrust: int = int(jetpack_state_counts.get("thrust", 0))
	var glide: int = int(jetpack_state_counts.get("glide", 0))
	var ground: int = int(jetpack_state_counts.get("ground", 0))
	var total: int = thrust + glide + ground
	if total <= 0:
		return ""
	var jetpack_part: String = " jetpack=thrust:%d/glide:%d/ground:%d" % [thrust, glide, ground]
	var hits: int = int(air_strike_event_counts.get("hits", 0))
	var post_hit: int = int(air_strike_event_counts.get("post_hit_frames", 0))
	if hits > 0 or post_hit > 0:
		jetpack_part += " air_strike=hits:%d/post_hit:%d" % [hits, post_hit]
	return jetpack_part


func _reset_jetpack_state_counts() -> void:
	jetpack_state_counts = {"thrust": 0, "glide": 0, "ground": 0}
	air_strike_event_counts = {"hits": 0, "post_hit_frames": 0}


func begin_sample() -> int:
	if not _is_enabled():
		return 0
	return Time.get_ticks_usec()


func finish_sample(label: String, start_usec: int) -> void:
	if start_usec <= 0:
		return
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	_store_sample(label, elapsed_usec)


func record_value_sample(label: String, elapsed_usec: int) -> void:
	if not _is_enabled() or elapsed_usec <= 0:
		return
	_store_sample(label, elapsed_usec)


func record_counter_sample(label: String, value: float) -> void:
	if not _is_enabled():
		return
	var counter: Dictionary = counters.get(label, {"count": 0, "total": 0.0, "max": 0.0})
	counter["count"] = int(counter.get("count", 0)) + 1
	counter["total"] = float(counter.get("total", 0.0)) + value
	counter["max"] = max(float(counter.get("max", 0.0)), value)
	counters[label] = counter


func _store_sample(label: String, elapsed_usec: int) -> void:
	var sample: Dictionary = samples.get(label, {"count": 0, "total_usec": 0, "max_usec": 0})
	sample["count"] = int(sample.get("count", 0)) + 1
	sample["total_usec"] = int(sample.get("total_usec", 0)) + elapsed_usec
	sample["max_usec"] = max(int(sample.get("max_usec", 0)), elapsed_usec)
	samples[label] = sample


func should_sample_detail(_label: String = "") -> bool:
	return _is_detail_enabled()


func is_enabled() -> bool:
	return _is_enabled()


func maybe_log(context: Dictionary = {}) -> void:
	if not _is_enabled() or samples.is_empty():
		return
	if not context.is_empty():
		remember_context(context)
	var now_msec := Time.get_ticks_msec()
	if now_msec < next_log_msec:
		return
	next_log_msec = now_msec + int(_get_log_interval_sec() * 1000.0)
	var header := _build_log_header(context)
	print("[BattlePerf-Boundary] ", header, " ", _build_boundary_summary())
	var gap_summary: String = _build_gap_summary()
	if gap_summary != "":
		print("[BattlePerf-Gap] ", header, " | ", gap_summary)
	var spike_summary: String = _build_spike_summary()
	if spike_summary != "":
		print("[BattlePerf-Spikes] ", header, " | ", spike_summary)
	var spike_window_summary: String = _build_spike_window_summary()
	if spike_window_summary != "":
		print("[BattlePerf-SpikeWindow] ", header, " | ", spike_window_summary)
	print("[BattlePerf-Physics] ", header, " | ", _build_physics_monitor_summary())
	if _is_detail_enabled() and _should_emit_spike_detail():
		print("[BattlePerf-Detail] ", header, " | ", _build_spike_detail_summary())
	if _is_sample_summary_enabled():
		print("[BattlePerf-Samples] ", header, " | ", _build_sample_summary())
	samples.clear()
	counters.clear()
	_reset_jetpack_state_counts()


func _build_log_header(context: Dictionary = {}) -> String:
	var header_context: Dictionary = _build_header_context(context)
	return "stage=%d char=%s weather=%s%s" % [
		int(header_context.get("current_stage", 1)),
		str(header_context.get("selected_character_type", "smasher")),
		str(header_context.get("active_weather_type", "")),
		_build_jetpack_label(),
	]


func _build_header_context(context: Dictionary = {}) -> Dictionary:
	var header_context: Dictionary = {}
	if not last_context.is_empty():
		header_context = last_context.duplicate(true)
	for key_value in context.keys():
		header_context[key_value] = context.get(key_value)
	_merge_scene_owner_header_context(header_context)
	return header_context


func _merge_scene_owner_header_context(header_context: Dictionary) -> void:
	var stage_value: Variant = _get_scene_owner_value("current_stage", null)
	if stage_value != null:
		header_context["current_stage"] = int(stage_value)
	var character_value: Variant = _get_scene_owner_value("selected_character_type", null)
	if character_value != null:
		header_context["selected_character_type"] = str(character_value)
	var weather_value: Variant = _get_scene_owner_value("active_weather_type", null)
	if weather_value == null:
		weather_value = _get_scene_owner_value("weather_type", null)
	if weather_value != null:
		header_context["active_weather_type"] = str(weather_value)


func _get_scene_owner_value(key: String, fallback: Variant) -> Variant:
	if scene_owner == null or not is_instance_valid(scene_owner):
		return fallback
	var value: Variant = scene_owner.get(key)
	if value == null:
		return fallback
	return value


func get_status() -> Dictionary:
	return {
		"env": PERF_LOG_ENV,
		"detail_env": PERF_DETAIL_ENV,
		"samples_env": PERF_SAMPLES_ENV,
		"interval_env": PERF_LOG_INTERVAL_ENV,
		"gap_threshold_env": PERF_GAP_THRESHOLD_ENV,
		"spike_threshold_env": PERF_SPIKE_THRESHOLD_ENV,
		"flag_path": PERF_LOG_FLAG_PATH,
		"detail_flag_path": PERF_DETAIL_FLAG_PATH,
		"samples_flag_path": PERF_SAMPLES_FLAG_PATH,
		"enabled": _is_enabled(),
		"detail_enabled": _is_detail_enabled(),
		"samples_enabled": _is_sample_summary_enabled(),
		"log_interval_sec": _get_log_interval_sec(),
		"spike_threshold_usec": _get_spike_threshold_usec(),
		"gap_threshold_msec": _get_gap_threshold_msec(),
		"sample_count": samples.size(),
	}


func _build_sample_summary() -> String:
	var keys := samples.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var sample: Dictionary = samples.get(key, {})
		var count: int = max(1, int(sample.get("count", 0)))
		var avg_usec: float = float(int(sample.get("total_usec", 0))) / float(count)
		parts.append("%s avg=%.1fus max=%dus n=%d" % [
			str(key),
			avg_usec,
			int(sample.get("max_usec", 0)),
			count,
		])
	return "; ".join(parts)


func _build_counter_summary() -> String:
	if counters.is_empty():
		return "-"
	var keys := counters.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var counter: Dictionary = counters.get(key, {})
		var count: int = max(1, int(counter.get("count", 0)))
		var avg_value: float = float(counter.get("total", 0.0)) / float(count)
		parts.append("%s=%.1f/%.1f(n%d)" % [
			str(key),
			avg_value,
			float(counter.get("max", 0.0)),
			count,
		])
	return "; ".join(parts)


func _build_spike_summary() -> String:
	var threshold_usec: int = _get_spike_threshold_usec()
	var keys := samples.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var sample: Dictionary = samples.get(key, {})
		var max_usec: int = int(sample.get("max_usec", 0))
		if max_usec < threshold_usec:
			continue
		if str(key).ends_with(".delta"):
			continue
		var count: int = max(1, int(sample.get("count", 0)))
		var avg_usec: float = float(int(sample.get("total_usec", 0))) / float(count)
		parts.append("%s avg=%.2fms max=%.2fms n=%d" % [
			str(key),
			avg_usec / 1000.0,
			float(max_usec) / 1000.0,
			count,
		])
	return "; ".join(parts)


func _build_gap_summary() -> String:
	var threshold_msec: float = _get_gap_threshold_msec()
	var metrics: Dictionary = _get_gap_metrics()
	var proc_gap_ms: float = float(metrics.get("proc_gap_ms", 0.0))
	var phys_gap_ms: float = float(metrics.get("phys_gap_ms", 0.0))
	var proc_after_draw_ms: float = float(metrics.get("proc_after_draw_ms", 0.0))
	var frame_idle_ms: float = float(metrics.get("frame_idle_ms", 0.0))
	var proc_delta_ms: float = _sample_avg_ms("process.shell.delta")
	var proc_delta_max_ms: float = _sample_max_ms("process.shell.delta")
	if max(proc_gap_ms, phys_gap_ms, proc_delta_max_ms) < threshold_msec:
		return ""
	var gap_class: String = _classify_gap(metrics, proc_delta_max_ms)
	var hot_summary: String = _build_gap_hot_sample_summary()
	var playfield_hot_summary: String = _build_gap_playfield_hot_sample_summary()
	var stage_hot_summary: String = _build_gap_stage_hot_sample_summary()
	var node_summary: String = _build_process_node_summary()
	var display_summary: String = _build_display_summary()
	var counter_summary: String = _build_counter_summary()
	return (
		"gap=mon-shell proc=%+.2fms phys=%+.2fms gap_v=%d class=%s render=calls=%d prims=%d"
		+ " | %s"
		+ " | proc_after_draw=%+.2fms(draw=%.2fms)"
		+ " | perf=proc-shell=%+.2fms proc-shell-draw=%+.2fms phys-shell=%+.2fms"
		+ " | monitor=proc=%.2fms phys=%.2fms"
		+ " | shell=proc=%.2fms phys=%.2fms"
		+ " | delta=proc=%.2fms(max=%.2f) idle=frame=%+.2fms"
		+ " | samples=proc=%d phys=%d draw=%d"
		+ " | hot=%s"
		+ " | playfield_hot=%s"
		+ " | stage_hot=%s"
		+ " | counters=%s"
		+ " | %s"
	) % [
		proc_gap_ms,
		phys_gap_ms,
		GAP_SUMMARY_VERSION,
		gap_class,
		int(metrics.get("draw_calls", 0)),
		int(metrics.get("primitives", 0)),
		display_summary,
		proc_after_draw_ms,
		float(metrics.get("draw_shell_ms", 0.0)),
		float(metrics.get("proc_gap_ms", 0.0)),
		proc_after_draw_ms,
		float(metrics.get("phys_gap_ms", 0.0)),
		float(metrics.get("process_ms", 0.0)),
		float(metrics.get("physics_ms", 0.0)),
		float(metrics.get("proc_shell_ms", 0.0)),
		float(metrics.get("phys_shell_ms", 0.0)),
		proc_delta_ms,
		proc_delta_max_ms,
		frame_idle_ms,
		int(metrics.get("proc_shell_count", 0)),
		int(metrics.get("phys_shell_count", 0)),
		int(metrics.get("draw_shell_count", 0)),
		hot_summary,
		playfield_hot_summary,
		stage_hot_summary,
		counter_summary,
		node_summary,
	]


# Detects per-window single-frame stalls that hot/spike filters can hide.
# `_build_spike_summary` ignores samples whose max stays under
# `DEFAULT_SPIKE_THRESHOLD_USEC` (8 ms), and `_build_gap_hot_sample_summary`
# requires avg >= 0.75 ms OR max >= 4 ms. A 28 ms shell.physics or 25 ms
# draw.shell stall surfaces in the parent label, but the actual sub-section
# that caused the spike often sits below those thresholds and disappears from
# the log. This helper emits an exhaustive list of every label sorted by max,
# scoped to windows where any of the three "felt stall" indicators tripped.
func _should_emit_spike_detail() -> bool:
	var delta_max: float = _sample_max_ms("process.shell.delta")
	var phys_shell_max: float = _sample_max_ms("physics.shell.total")
	var draw_shell_max: float = _sample_max_ms("draw.shell.total")
	if draw_shell_max <= 0.0:
		draw_shell_max = _sample_max_ms("draw.frame.total")
	return (
		delta_max >= SPIKE_DETAIL_DELTA_TRIGGER_MSEC
		or phys_shell_max >= SPIKE_DETAIL_PHYS_TRIGGER_MSEC
		or draw_shell_max >= SPIKE_DETAIL_DRAW_TRIGGER_MSEC
	)


func _build_spike_detail_summary() -> String:
	var entries: Array[Dictionary] = []
	for key_value in samples.keys():
		var label := str(key_value)
		if label.ends_with(".delta"):
			continue
		var sample: Dictionary = samples.get(label, {})
		var max_ms: float = float(int(sample.get("max_usec", 0))) / 1000.0
		var count: int = max(1, int(sample.get("count", 0)))
		var avg_ms: float = float(int(sample.get("total_usec", 0))) / float(count) / 1000.0
		entries.append({
			"label": label,
			"max_ms": max_ms,
			"avg_ms": avg_ms,
			"count": count,
		})
	if entries.is_empty():
		return "-"
	entries.sort_custom(Callable(self, "_sort_spike_detail_desc"))
	var parts: Array[String] = []
	var limit: int = min(entries.size(), SPIKE_DETAIL_LIMIT)
	for index in range(limit):
		var entry: Dictionary = entries[index]
		parts.append("%s=%.2f/%.2fms(n%d)" % [
			str(entry.get("label", "")),
			float(entry.get("avg_ms", 0.0)),
			float(entry.get("max_ms", 0.0)),
			int(entry.get("count", 0)),
		])
	return "; ".join(parts)


func _sort_spike_detail_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_max: float = float(a.get("max_ms", 0.0))
	var b_max: float = float(b.get("max_ms", 0.0))
	if not is_equal_approx(a_max, b_max):
		return a_max > b_max
	return float(a.get("avg_ms", 0.0)) > float(b.get("avg_ms", 0.0))


func _build_spike_window_summary() -> String:
	return spike_window_reporter.build(
		samples,
		_build_counter_summary(),
		GAP_PLAYFIELD_HOT_PREFIXES,
		GAP_STAGE_HOT_PREFIXES
	)


# Engine-internal counters that explain the gap between
# `Performance.TIME_PHYSICS_PROCESS` and the user-script `_physics_process`
# shell time. None of the time spent here is captured by `begin_sample`/
# `finish_sample` because it lives inside the C++ PhysicsServer2D pass
# (broadphase, pair management, island solver, constraint solver). Surfacing
# these counts lets a perf capture distinguish three failure modes:
#   - Pair explosion (many overlapping CollisionShape2D in a tight area)
#   - Dormancy miss (active body count stays high even when nothing moves)
#   - Node leak (object/node counts climb across rounds or stages)
# `active_pairs / island_count` of 0 with a high `phys-shell` gap means the
# cost is elsewhere (audio mixing, AnimationPlayer, ProcessMode internals).
func _build_physics_monitor_summary() -> String:
	var active_bodies_2d: int = int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
	var collision_pairs_2d: int = int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
	var island_count_2d: int = int(Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT))
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphan_node_count: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var object_count: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resource_count: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	return "phys2d=active=%d pairs=%d islands=%d | nodes=total=%d orphans=%d | objects=%d resources=%d" % [
		active_bodies_2d,
		collision_pairs_2d,
		island_count_2d,
		node_count,
		orphan_node_count,
		object_count,
		resource_count,
	]


func _get_gap_metrics() -> Dictionary:
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var phys_total_ms: float = _sample_avg_ms("physics.frame.total")
	var proc_total_ms: float = _sample_avg_ms("process.frame.total")
	var phys_shell_ms: float = _sample_avg_ms("physics.shell.total")
	var proc_shell_ms: float = _sample_avg_ms("process.shell.total")
	var draw_shell_ms: float = _sample_avg_ms("draw.shell.total")
	var phys_shell_max_ms: float = _sample_max_ms("physics.shell.total")
	var proc_shell_max_ms: float = _sample_max_ms("process.shell.total")
	var draw_shell_max_ms: float = _sample_max_ms("draw.shell.total")
	var phys_shell_count: int = _sample_count("physics.shell.total")
	var proc_shell_count: int = _sample_count("process.shell.total")
	var draw_shell_count: int = _sample_count("draw.shell.total")
	var proc_delta_ms: float = _sample_avg_ms("process.shell.delta")
	if draw_shell_ms <= 0.0:
		draw_shell_ms = _sample_avg_ms("draw.frame.total")
		draw_shell_max_ms = _sample_max_ms("draw.frame.total")
		draw_shell_count = _sample_count("draw.frame.total")
	if draw_shell_ms <= 0.0:
		draw_shell_ms = _sample_avg_ms("00.playfield_frame_total")
		draw_shell_max_ms = _sample_max_ms("00.playfield_frame_total")
		draw_shell_count = _sample_count("00.playfield_frame_total")
	var known_proc_plus_draw_ms: float = (proc_shell_ms if proc_shell_ms > 0.0 else proc_total_ms) + draw_shell_ms
	return {
		"process_ms": process_ms,
		"physics_ms": physics_ms,
		"draw_calls": draw_calls,
		"primitives": primitives,
		"phys_shell_ms": phys_shell_ms,
		"proc_shell_ms": proc_shell_ms,
		"draw_shell_ms": draw_shell_ms,
		"phys_shell_max_ms": phys_shell_max_ms,
		"proc_shell_max_ms": proc_shell_max_ms,
		"draw_shell_max_ms": draw_shell_max_ms,
		"phys_shell_count": phys_shell_count,
		"proc_shell_count": proc_shell_count,
		"draw_shell_count": draw_shell_count,
		"physics_2d_active": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		"physics_2d_pairs": int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
		"physics_2d_islands": int(Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)),
		"phys_gap_ms": physics_ms - (phys_shell_ms if phys_shell_ms > 0.0 else phys_total_ms),
		"proc_gap_ms": process_ms - (proc_shell_ms if proc_shell_ms > 0.0 else proc_total_ms),
		"proc_after_draw_ms": process_ms - known_proc_plus_draw_ms,
		"frame_idle_ms": proc_delta_ms - process_ms,
	}


func _classify_gap(metrics: Dictionary, proc_delta_max_ms: float) -> String:
	var classes: Array[String] = []
	var proc_gap_ms: float = float(metrics.get("proc_gap_ms", 0.0))
	var phys_gap_ms: float = float(metrics.get("phys_gap_ms", 0.0))
	var proc_after_draw_ms: float = float(metrics.get("proc_after_draw_ms", 0.0))
	var phys_shell_ms: float = float(metrics.get("phys_shell_ms", 0.0))
	var draw_shell_ms: float = float(metrics.get("draw_shell_ms", 0.0))
	var draw_calls: int = int(metrics.get("draw_calls", 0))
	var primitives: int = int(metrics.get("primitives", 0))
	var proc_shell_count: int = int(metrics.get("proc_shell_count", 0))
	var phys_shell_count: int = int(metrics.get("phys_shell_count", 0))
	var draw_shell_count: int = int(metrics.get("draw_shell_count", 0))
	var process_monitor_lag: bool = _is_process_monitor_lag(metrics, proc_delta_max_ms)
	var physics_monitor_lag: bool = _is_physics_monitor_lag(metrics)
	if proc_delta_max_ms >= GAP_FRAME_PACING_DELTA_MSEC:
		classes.append("frame-pacing")
	if draw_shell_ms >= GAP_RENDER_HEAVY_DRAW_MSEC or draw_calls >= GAP_RENDER_HEAVY_CALLS or primitives >= GAP_RENDER_HEAVY_PRIMITIVES:
		classes.append("render-heavy")
	if process_monitor_lag:
		classes.append("monitor-process-lag")
	elif proc_after_draw_ms >= GAP_ENGINE_PROCESS_MSEC and proc_gap_ms >= GAP_ENGINE_PROCESS_MSEC:
		classes.append("engine-process")
	if phys_gap_ms >= GAP_ENGINE_PHYSICS_MSEC and phys_shell_ms <= GAP_ENGINE_PHYSICS_MSEC:
		if physics_monitor_lag:
			classes.append("monitor-physics-lag")
		if _is_physics_cadence_gap(proc_shell_count, phys_shell_count, draw_shell_count):
			classes.append("physics-cadence")
		elif not physics_monitor_lag:
			classes.append("engine-physics")
	if classes.is_empty():
		classes.append("baseline-gap")
	return ",".join(classes)


func _is_physics_cadence_gap(proc_shell_count: int, phys_shell_count: int, draw_shell_count: int = 0) -> bool:
	if phys_shell_count <= 0:
		return false
	if draw_shell_count > 0 and phys_shell_count < int(ceil(float(draw_shell_count) * 0.75)):
		return true
	if proc_shell_count > 0 and phys_shell_count < int(ceil(float(proc_shell_count) * 0.75)):
		return true
	return false


func _is_process_monitor_lag(metrics: Dictionary, proc_delta_max_ms: float) -> bool:
	var process_ms: float = float(metrics.get("process_ms", 0.0))
	var proc_after_draw_ms: float = float(metrics.get("proc_after_draw_ms", 0.0))
	if process_ms < GAP_ENGINE_PROCESS_MSEC or proc_after_draw_ms < GAP_ENGINE_PROCESS_MSEC:
		return false
	var frame_idle_ms: float = float(metrics.get("frame_idle_ms", 0.0))
	if frame_idle_ms <= -GAP_MONITOR_STALE_MARGIN_MSEC:
		return true
	var local_max_ms: float = max(
		proc_delta_max_ms,
		float(metrics.get("proc_shell_max_ms", 0.0)) + float(metrics.get("draw_shell_max_ms", 0.0))
	)
	return process_ms > local_max_ms + GAP_MONITOR_STALE_MARGIN_MSEC


func _is_physics_monitor_lag(metrics: Dictionary) -> bool:
	var physics_ms: float = float(metrics.get("physics_ms", 0.0))
	var phys_gap_ms: float = float(metrics.get("phys_gap_ms", 0.0))
	if physics_ms < GAP_ENGINE_PHYSICS_MSEC or phys_gap_ms < GAP_ENGINE_PHYSICS_MSEC:
		return false
	var phys_shell_ms: float = float(metrics.get("phys_shell_ms", 0.0))
	var phys_shell_max_ms: float = float(metrics.get("phys_shell_max_ms", 0.0))
	var local_max_ms: float = max(phys_shell_ms, phys_shell_max_ms)
	if physics_ms <= local_max_ms + GAP_MONITOR_STALE_MARGIN_MSEC:
		return false
	var active_bodies_2d: int = int(metrics.get("physics_2d_active", -1))
	var collision_pairs_2d: int = int(metrics.get("physics_2d_pairs", -1))
	var island_count_2d: int = int(metrics.get("physics_2d_islands", -1))
	return active_bodies_2d == 0 and collision_pairs_2d == 0 and island_count_2d == 0


func _build_gap_hot_sample_summary() -> String:
	var entries: Array[Dictionary] = []
	for key_value in samples.keys():
		var label := str(key_value)
		if _is_gap_hot_aggregate_label(label):
			continue
		var sample: Dictionary = samples.get(label, {})
		var count: int = max(1, int(sample.get("count", 0)))
		var avg_ms: float = float(int(sample.get("total_usec", 0))) / float(count) / 1000.0
		var max_ms: float = float(int(sample.get("max_usec", 0))) / 1000.0
		if avg_ms < GAP_HOT_SAMPLE_AVG_MSEC and max_ms < GAP_HOT_SAMPLE_MAX_MSEC:
			continue
		entries.append({
			"label": label,
			"avg_ms": avg_ms,
			"max_ms": max_ms,
			"count": count,
		})
	if entries.is_empty():
		return "-"
	entries.sort_custom(Callable(self, "_sort_gap_hot_sample_desc"))
	var parts: Array[String] = []
	var limit: int = min(entries.size(), GAP_HOT_SAMPLE_LIMIT)
	for index in range(limit):
		var entry: Dictionary = entries[index]
		parts.append("%s=%.2f/%.2fms(n%d)" % [
			str(entry.get("label", "")),
			float(entry.get("avg_ms", 0.0)),
			float(entry.get("max_ms", 0.0)),
			int(entry.get("count", 0)),
		])
	return "; ".join(parts)


func _build_gap_stage_hot_sample_summary() -> String:
	var entries: Array[Dictionary] = []
	for key_value in samples.keys():
		var label := str(key_value)
		if not _is_gap_stage_hot_label(label):
			continue
		var sample: Dictionary = samples.get(label, {})
		var count: int = max(1, int(sample.get("count", 0)))
		var avg_ms: float = float(int(sample.get("total_usec", 0))) / float(count) / 1000.0
		var max_ms: float = float(int(sample.get("max_usec", 0))) / 1000.0
		entries.append({
			"label": label,
			"avg_ms": avg_ms,
			"max_ms": max_ms,
			"count": count,
		})
	if entries.is_empty():
		return "-"
	entries.sort_custom(Callable(self, "_sort_gap_hot_sample_desc"))
	var parts: Array[String] = []
	var limit: int = min(entries.size(), GAP_STAGE_HOT_SAMPLE_LIMIT)
	for index in range(limit):
		var entry: Dictionary = entries[index]
		parts.append("%s=%.2f/%.2fms(n%d)" % [
			str(entry.get("label", "")),
			float(entry.get("avg_ms", 0.0)),
			float(entry.get("max_ms", 0.0)),
			int(entry.get("count", 0)),
		])
	return "; ".join(parts)


func _build_gap_playfield_hot_sample_summary() -> String:
	var entries: Array[Dictionary] = []
	for key_value in samples.keys():
		var label := str(key_value)
		if not _is_gap_playfield_hot_label(label):
			continue
		var sample: Dictionary = samples.get(label, {})
		var count: int = max(1, int(sample.get("count", 0)))
		var avg_ms: float = float(int(sample.get("total_usec", 0))) / float(count) / 1000.0
		var max_ms: float = float(int(sample.get("max_usec", 0))) / 1000.0
		entries.append({
			"label": label,
			"avg_ms": avg_ms,
			"max_ms": max_ms,
			"count": count,
		})
	if entries.is_empty():
		return "-"
	entries.sort_custom(Callable(self, "_sort_gap_hot_sample_desc"))
	var parts: Array[String] = []
	var limit: int = min(entries.size(), GAP_PLAYFIELD_HOT_SAMPLE_LIMIT)
	for index in range(limit):
		var entry: Dictionary = entries[index]
		parts.append("%s=%.2f/%.2fms(n%d)" % [
			str(entry.get("label", "")),
			float(entry.get("avg_ms", 0.0)),
			float(entry.get("max_ms", 0.0)),
			int(entry.get("count", 0)),
		])
	return "; ".join(parts)


func _sort_gap_hot_sample_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_avg: float = float(a.get("avg_ms", 0.0))
	var b_avg: float = float(b.get("avg_ms", 0.0))
	if not is_equal_approx(a_avg, b_avg):
		return a_avg > b_avg
	return float(a.get("max_ms", 0.0)) > float(b.get("max_ms", 0.0))


func _is_gap_hot_aggregate_label(label: String) -> bool:
	if label.ends_with(".delta"):
		return true
	return label in [
		"physics.shell.total",
		"physics.frame.total",
		"process.shell.total",
		"process.frame.total",
		"draw.shell.total",
		"draw.frame.total",
		"draw.scene.total",
	]


func _is_gap_stage_hot_label(label: String) -> bool:
	for prefix in GAP_STAGE_HOT_PREFIXES:
		if label.begins_with(str(prefix)):
			return true
	return false


func _is_gap_playfield_hot_label(label: String) -> bool:
	if label == "00.playfield_frame_total":
		return false
	if label.length() >= 3 and label.substr(0, 2).is_valid_int() and label.substr(2, 1) == ".":
		return true
	for prefix in GAP_PLAYFIELD_HOT_PREFIXES:
		if label.begins_with(str(prefix)):
			return true
	return false


func _build_process_node_summary() -> String:
	return process_node_reporter.build(scene_owner)


func _build_monitor_summary() -> String:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return "fps=%.1f process=%.2fms physics=%.2fms draw_calls=%d primitives=%d" % [
		fps,
		process_ms,
		physics_ms,
		int(draw_calls),
		int(primitives),
	]


func _build_boundary_summary() -> String:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var phys_total_ms: float = _sample_avg_ms("physics.frame.total")
	var phys_total_max_ms: float = _sample_max_ms("physics.frame.total")
	var proc_total_ms: float = _sample_avg_ms("process.frame.total")
	var proc_total_max_ms: float = _sample_max_ms("process.frame.total")
	var draw_total_ms: float = _sample_avg_ms("draw.frame.total")
	var draw_total_max_ms: float = _sample_max_ms("draw.frame.total")
	var playfield_draw_ms: float = _sample_avg_ms("00.playfield_frame_total")
	var playfield_draw_max_ms: float = _sample_max_ms("00.playfield_frame_total")
	if draw_total_ms <= 0.0:
		draw_total_ms = playfield_draw_ms
		draw_total_max_ms = playfield_draw_max_ms
	var phys_shell_ms: float = _sample_avg_ms("physics.shell.total")
	var phys_shell_max_ms: float = _sample_max_ms("physics.shell.total")
	var proc_shell_ms: float = _sample_avg_ms("process.shell.total")
	var proc_shell_max_ms: float = _sample_max_ms("process.shell.total")
	var draw_shell_ms: float = _sample_avg_ms("draw.shell.total")
	var draw_shell_max_ms: float = _sample_max_ms("draw.shell.total")
	var proc_delta_ms: float = _sample_avg_ms("process.shell.delta")
	var proc_delta_max_ms: float = _sample_max_ms("process.shell.delta")
	var phys_delta_ms: float = _sample_avg_ms("physics.shell.delta")
	var phys_delta_max_ms: float = _sample_max_ms("physics.shell.delta")
	var phys_gap_ms: float = physics_ms - (phys_shell_ms if phys_shell_ms > 0.0 else phys_total_ms)
	var proc_gap_ms: float = process_ms - (proc_shell_ms if proc_shell_ms > 0.0 else proc_total_ms)
	var draw_accounted_ms: float = draw_shell_ms if draw_shell_ms > 0.0 else draw_total_ms
	var proc_after_draw_gap_ms: float = process_ms - ((proc_shell_ms if proc_shell_ms > 0.0 else proc_total_ms) + draw_accounted_ms)
	var frame_idle_ms: float = proc_delta_ms - process_ms
	var phys_shell_gap_ms: float = phys_shell_ms - phys_total_ms if phys_shell_ms > 0.0 else 0.0
	var proc_shell_gap_ms: float = proc_shell_ms - proc_total_ms if proc_shell_ms > 0.0 else 0.0
	var draw_shell_gap_ms: float = draw_shell_ms - draw_total_ms if draw_shell_ms > 0.0 else 0.0
	var display_summary: String = _build_display_summary()
	return (
		"monitor=fps=%.1f proc=%.2fms phys=%.2fms calls=%d prims=%d"
		+ " | %s"
		+ " | delta=proc=%.2fms(max=%.2f) phys=%.2fms(max=%.2f)"
		+ " | shell=phys=%.2fms(max=%.2f) proc=%.2fms(max=%.2f) draw=%.2fms(max=%.2f)"
		+ " | frame=phys=%.2fms(max=%.2f) proc=%.2fms(max=%.2f) draw=%.2fms(max=%.2f) playfield=%.2fms(max=%.2f)"
		+ " | gap=mon-shell phys=%+.2fms proc=%+.2fms proc_after_draw=%+.2fms idle=frame=%+.2fms shell-frame phys=%+.2fms proc=%+.2fms draw=%+.2fms"
	) % [
		fps,
		process_ms,
		physics_ms,
		int(draw_calls),
		int(primitives),
		display_summary,
		proc_delta_ms,
		proc_delta_max_ms,
		phys_delta_ms,
		phys_delta_max_ms,
		phys_shell_ms,
		phys_shell_max_ms,
		proc_shell_ms,
		proc_shell_max_ms,
		draw_shell_ms,
		draw_shell_max_ms,
		phys_total_ms,
		phys_total_max_ms,
		proc_total_ms,
		proc_total_max_ms,
		draw_total_ms,
		draw_total_max_ms,
		playfield_draw_ms,
		playfield_draw_max_ms,
		phys_gap_ms,
		proc_gap_ms,
		proc_after_draw_gap_ms,
		frame_idle_ms,
		phys_shell_gap_ms,
		proc_shell_gap_ms,
		draw_shell_gap_ms,
	]


func _build_display_summary() -> String:
	var window: Window = null
	if scene_owner != null and scene_owner.is_inside_tree():
		window = scene_owner.get_window()
	var screen_index: int = DisplayServer.SCREEN_OF_MAIN_WINDOW
	var window_mode: int = -1
	if window != null:
		screen_index = window.current_screen
		window_mode = window.mode
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate(screen_index)
	if refresh_rate <= 0.0:
		refresh_rate = 0.0
	var max_fps: int = int(Engine.get("max_fps"))
	var physics_ticks: int = int(Engine.physics_ticks_per_second)
	var layout: Object = BattleViewLayout.new()
	var cap_label: String = _render_fps_cap_label(window, layout)
	var vsync_mode: int = int(DisplayServer.window_get_vsync_mode())
	var saved_vsync_mode: int = int(layout.get_saved_vsync_mode())
	var saved_window_mode := _format_display_token(str(layout.get_saved_display_mode()))
	var remember_window_mode := "on" if bool(layout.get_remember_display_mode()) else "off"
	var embedded_mode := "on" if Engine.is_embedded_in_editor() else "off"
	var settings_path := _format_display_token(ProjectSettings.globalize_path(BattleViewLayout.SETTINGS_PATH))
	var configure_summary := _format_display_token(BattleViewLayout.get_configure_window_summary())
	var save_summary := _format_display_token(BattleViewLayout.get_settings_save_summary())
	var load_summary := _format_display_token(BattleViewLayout.get_settings_load_summary())
	var interp_fraction: float = Engine.get_physics_interpolation_fraction()
	var lod_scale: float = BattleRenderQuality.effect_scale(last_context)
	return "display=screen=%d hz=%.1f max_fps=%d ptick=%d cap=%s vsync=%s window=%s saved_window=%s remember=%s saved_vsync=%s embedded=%s settings=%s configure=%s save=%s load=%s driver=%s api=%s interp=%.2f lod=%.2f" % [
		screen_index,
		refresh_rate,
		max_fps,
		physics_ticks,
		cap_label,
		_vsync_mode_label(vsync_mode),
		_window_mode_label(window_mode),
		saved_window_mode,
		remember_window_mode,
		_vsync_mode_label(saved_vsync_mode),
		embedded_mode,
		settings_path,
		configure_summary,
		save_summary,
		load_summary,
		_render_driver_label(),
		_video_adapter_api_label(),
		interp_fraction,
		lod_scale,
	]


func _render_fps_cap_label(window: Window, layout: Object = null) -> String:
	if layout == null:
		layout = BattleViewLayout.new()
	var cap: int = int(layout.get_render_fps_cap(window))
	return _format_display_token(str(layout.get_render_fps_cap_label(cap, window)))


func _render_driver_label() -> String:
	if OS.has_method("get_current_rendering_driver_name"):
		return _format_display_token(str(OS.call("get_current_rendering_driver_name")))
	return _format_display_token(str(ProjectSettings.get_setting("rendering/rendering_device/driver.windows", "unknown")))


func _video_adapter_api_label() -> String:
	if RenderingServer.has_method("get_video_adapter_api_version"):
		return _format_display_token(str(RenderingServer.call("get_video_adapter_api_version")))
	return "unknown"


func _format_display_token(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized == "":
		return "unknown"
	return normalized.replace(" ", "_").replace("|", "/")


func _vsync_mode_label(mode: int) -> String:
	if mode == BattleViewLayout.VSYNC_MODE_AUTO:
		return "auto"
	if mode == DisplayServer.VSYNC_DISABLED:
		return "off"
	if mode == DisplayServer.VSYNC_ADAPTIVE:
		return "adaptive"
	if mode == DisplayServer.VSYNC_MAILBOX:
		return "mailbox"
	return "on"


func _window_mode_label(mode: int) -> String:
	if mode == Window.MODE_FULLSCREEN:
		return "fullscreen"
	if mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return "exclusive"
	if mode == Window.MODE_MINIMIZED:
		return "minimized"
	if mode == Window.MODE_MAXIMIZED:
		return "maximized"
	return "windowed"


func _sample_avg_ms(label: String) -> float:
	var sample: Dictionary = samples.get(label, {})
	var count: int = int(sample.get("count", 0))
	if count <= 0:
		return 0.0
	var total_usec: int = int(sample.get("total_usec", 0))
	return float(total_usec) / float(count) / 1000.0


func _sample_count(label: String) -> int:
	var sample: Dictionary = samples.get(label, {})
	return int(sample.get("count", 0))


func _sample_max_ms(label: String) -> float:
	var sample: Dictionary = samples.get(label, {})
	return float(int(sample.get("max_usec", 0))) / 1000.0


func _is_enabled() -> bool:
	if log_checked:
		return log_enabled
	log_checked = true
	var value := OS.get_environment(PERF_LOG_ENV).strip_edges().to_lower()
	log_enabled = value in ["1", "true", "yes", "on"] or FileAccess.file_exists(PERF_LOG_FLAG_PATH)
	return log_enabled


func _is_detail_enabled() -> bool:
	if detail_checked:
		return detail_enabled
	detail_checked = true
	var value := OS.get_environment(PERF_DETAIL_ENV).strip_edges().to_lower()
	detail_enabled = value in ["1", "true", "yes", "on"] or FileAccess.file_exists(PERF_DETAIL_FLAG_PATH)
	return detail_enabled


func _is_sample_summary_enabled() -> bool:
	if sample_summary_checked:
		return sample_summary_enabled
	sample_summary_checked = true
	var value := OS.get_environment(PERF_SAMPLES_ENV).strip_edges().to_lower()
	sample_summary_enabled = value in ["1", "true", "yes", "on"] or FileAccess.file_exists(PERF_SAMPLES_FLAG_PATH)
	return sample_summary_enabled


func _get_log_interval_sec() -> float:
	if log_interval_checked:
		return log_interval_sec
	log_interval_checked = true
	var value := OS.get_environment(PERF_LOG_INTERVAL_ENV).strip_edges()
	if value.is_valid_float():
		log_interval_sec = clampf(float(value), 0.1, 60.0)
	return log_interval_sec


func _get_spike_threshold_usec() -> int:
	if spike_threshold_checked:
		return spike_threshold_usec
	spike_threshold_checked = true
	var value := OS.get_environment(PERF_SPIKE_THRESHOLD_ENV).strip_edges()
	if value.is_valid_int():
		spike_threshold_usec = max(1, int(value))
	return spike_threshold_usec


func _get_gap_threshold_msec() -> float:
	if gap_threshold_checked:
		return gap_threshold_msec
	gap_threshold_checked = true
	var value := OS.get_environment(PERF_GAP_THRESHOLD_ENV).strip_edges()
	if value.is_valid_float():
		gap_threshold_msec = max(0.1, float(value))
	return gap_threshold_msec
