extends RefCounted

# Pure classifier for metrics captured by BattlePerfLogger. This module does
# not read Performance monitors or mutate sample windows.

const GAP_FRAME_PACING_DELTA_MSEC := 30.0
const GAP_RENDER_HEAVY_DRAW_MSEC := 10.0
const GAP_RENDER_HEAVY_CALLS := 800
const GAP_RENDER_HEAVY_PRIMITIVES := 32000
const GAP_ENGINE_PROCESS_MSEC := 5.0
const GAP_ENGINE_PHYSICS_MSEC := 8.0
const GAP_MONITOR_STALE_MARGIN_MSEC := 8.0


static func classify(metrics: Dictionary, process_delta_max_msec: float) -> String:
	var classes: Array[String] = []
	var process_gap_msec := float(metrics.get("proc_gap_ms", 0.0))
	var physics_gap_msec := float(metrics.get("phys_gap_ms", 0.0))
	var process_after_draw_msec := float(metrics.get("proc_after_draw_ms", 0.0))
	var physics_shell_msec := float(metrics.get("phys_shell_ms", 0.0))
	var draw_shell_msec := float(metrics.get("draw_shell_ms", 0.0))
	var draw_calls := int(metrics.get("draw_calls", 0))
	var primitives := int(metrics.get("primitives", 0))
	var process_shell_count := int(metrics.get("proc_shell_count", 0))
	var physics_shell_count := int(metrics.get("phys_shell_count", 0))
	var draw_shell_count := int(metrics.get("draw_shell_count", 0))
	var process_monitor_lag := is_process_monitor_lag(metrics, process_delta_max_msec)
	var physics_monitor_lag := is_physics_monitor_lag(metrics)
	if process_delta_max_msec >= GAP_FRAME_PACING_DELTA_MSEC:
		classes.append("frame-pacing")
	if draw_shell_msec >= GAP_RENDER_HEAVY_DRAW_MSEC or draw_calls >= GAP_RENDER_HEAVY_CALLS or primitives >= GAP_RENDER_HEAVY_PRIMITIVES:
		classes.append("render-heavy")
	if process_monitor_lag:
		classes.append("monitor-process-lag")
	elif process_after_draw_msec >= GAP_ENGINE_PROCESS_MSEC and process_gap_msec >= GAP_ENGINE_PROCESS_MSEC:
		classes.append("engine-process")
	if physics_gap_msec >= GAP_ENGINE_PHYSICS_MSEC and physics_shell_msec <= GAP_ENGINE_PHYSICS_MSEC:
		if physics_monitor_lag:
			classes.append("monitor-physics-lag")
		if is_physics_cadence_gap(process_shell_count, physics_shell_count, draw_shell_count):
			classes.append("physics-cadence")
		elif not physics_monitor_lag:
			classes.append("engine-physics")
	if classes.is_empty():
		classes.append("baseline-gap")
	return ",".join(classes)


static func is_physics_cadence_gap(process_shell_count: int, physics_shell_count: int, draw_shell_count: int = 0) -> bool:
	if physics_shell_count <= 0:
		return false
	if draw_shell_count > 0 and physics_shell_count < int(ceil(float(draw_shell_count) * 0.75)):
		return true
	if process_shell_count > 0 and physics_shell_count < int(ceil(float(process_shell_count) * 0.75)):
		return true
	return false


static func is_process_monitor_lag(metrics: Dictionary, process_delta_max_msec: float) -> bool:
	var process_msec := float(metrics.get("process_ms", 0.0))
	var process_after_draw_msec := float(metrics.get("proc_after_draw_ms", 0.0))
	if process_msec < GAP_ENGINE_PROCESS_MSEC or process_after_draw_msec < GAP_ENGINE_PROCESS_MSEC:
		return false
	var frame_idle_msec := float(metrics.get("frame_idle_ms", 0.0))
	if frame_idle_msec <= -GAP_MONITOR_STALE_MARGIN_MSEC:
		return true
	var local_max_msec := maxf(
		process_delta_max_msec,
		float(metrics.get("proc_shell_max_ms", 0.0)) + float(metrics.get("draw_shell_max_ms", 0.0))
	)
	return process_msec > local_max_msec + GAP_MONITOR_STALE_MARGIN_MSEC


static func is_physics_monitor_lag(metrics: Dictionary) -> bool:
	var physics_msec := float(metrics.get("physics_ms", 0.0))
	var physics_gap_msec := float(metrics.get("phys_gap_ms", 0.0))
	if physics_msec < GAP_ENGINE_PHYSICS_MSEC or physics_gap_msec < GAP_ENGINE_PHYSICS_MSEC:
		return false
	var physics_shell_msec := float(metrics.get("phys_shell_ms", 0.0))
	var physics_shell_max_msec := float(metrics.get("phys_shell_max_ms", 0.0))
	var local_max_msec := maxf(physics_shell_msec, physics_shell_max_msec)
	if physics_msec <= local_max_msec + GAP_MONITOR_STALE_MARGIN_MSEC:
		return false
	return (
		int(metrics.get("physics_2d_active", -1)) == 0
		and int(metrics.get("physics_2d_pairs", -1)) == 0
		and int(metrics.get("physics_2d_islands", -1)) == 0
	)
