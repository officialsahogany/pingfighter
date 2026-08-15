extends Control

# R3-D production transition owner. It keeps the R3-C lifecycle hidden behind
# an opaque, progressing loading surface until the same call that activates the
# exterior also dismisses the loading cover. Failure never routes to R1.

const BattleLoadingStainedGlassHost := preload("res://scripts/core/battle_loading_stained_glass_host.gd")
const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")
const PlazaR3LifecyclePrewarmCandidate := preload("res://scripts/plaza/plaza_r3_lifecycle_prewarm_candidate.gd")

const SCHEMA_VERSION := "plaza_r3d_production_entry_host_v1"
const MAX_STALLED_UPDATE_COUNT := 360
const MAX_TOTAL_UPDATE_COUNT := 2160
const PHASE_IDLE := "idle"
const PHASE_LOADING := "loading"
const PHASE_READY := "ready"
const PHASE_EXTERIOR := "exterior"
const PHASE_INTERIOR := "interior"
const PHASE_REJECTED := "rejected"
const PHASE_TORN_DOWN := "torn_down"

var _phase := PHASE_IDLE
var _rejection_reason := "not_started"
var _request: Dictionary = {}
var _lifecycle: Control = null
var _loading_host: Control = null
var _test_lifecycle: Control = null

var _progress := 0.0
var _last_progress_token := ""
var _total_update_count := 0
var _stalled_update_count := 0
var _loading_started_usec := 0
var _prewarm_ready_usec := -1
var _activation_usec := -1
var _loading_hidden_usec := -1
var _loading_first_draw_usec := -1
var _loading_draw_count := 0
var _pre_reveal_runtime_visible_count := 0
var _atomic_reveal_count := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1199
	set_process(false)


func _ready() -> void:
	_ensure_nodes()
	queue_redraw()


func _draw() -> void:
	if _phase not in [PHASE_LOADING, PHASE_READY, PHASE_REJECTED]:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.010, 0.018, 1.0))
	_loading_draw_count += 1
	if _loading_first_draw_usec < 0:
		_loading_first_draw_usec = Time.get_ticks_usec()


func set_lifecycle_for_test(value: Control) -> bool:
	if _phase != PHASE_IDLE or is_inside_tree():
		return false
	_test_lifecycle = value
	return value != null


func begin_entry(config: Dictionary) -> bool:
	if _phase != PHASE_IDLE:
		return _reject("entry_already_started")
	_ensure_nodes()
	if _lifecycle == null or not is_instance_valid(_lifecycle):
		return _reject("lifecycle_missing")
	_request = config.duplicate(true)
	var render_value: Variant = config.get("render_size", Vector2.ZERO)
	if not (render_value is Vector2):
		return _reject("render_size_type_invalid")
	size = render_value as Vector2
	if not size.is_finite() or size.x <= 1.0 or size.y <= 1.0:
		return _reject("render_size_invalid")
	_lifecycle.position = Vector2.ZERO
	_lifecycle.size = size
	_loading_started_usec = Time.get_ticks_usec()
	_phase = PHASE_LOADING
	_rejection_reason = ""
	_sync_loading_surface("환계도 전개 중", 0.0)
	queue_redraw()
	if not bool(_lifecycle.call("begin_prewarm", config)):
		return _reject(_lifecycle_rejection("prewarm_begin_failed"))
	_sync_progress_from_lifecycle(true)
	set_process(false)
	return true


func advance_entry(_delta: float) -> bool:
	if _phase == PHASE_READY:
		return true
	if _phase != PHASE_LOADING:
		return false
	_total_update_count += 1
	if _total_update_count > MAX_TOTAL_UPDATE_COUNT:
		return _reject("prewarm_total_budget_exhausted")
	var completed := bool(_lifecycle.call("advance_prewarm_step"))
	if _lifecycle_rejected():
		return _reject(_lifecycle_rejection("prewarm_rejected"))
	_sync_progress_from_lifecycle(false)
	if _lifecycle.visible:
		_pre_reveal_runtime_visible_count += 1
		return _reject("r3_visible_before_atomic_reveal")
	if completed:
		_prewarm_ready_usec = Time.get_ticks_usec()
		_progress = 1.0
		_phase = PHASE_READY
		_sync_loading_surface("환계도 준비 완료", 1.0)
		return true
	if _stalled_update_count > MAX_STALLED_UPDATE_COUNT:
		return _reject("prewarm_stalled")
	return false


func activate_under_loading() -> bool:
	if _phase != PHASE_READY:
		return _reject("activation_before_ready")
	if _loading_host == null or not _loading_host.visible or _loading_draw_count <= 0:
		return _reject("loading_cover_not_drawn")
	if not bool(_lifecycle.call("activate_exterior")):
		return _reject(_lifecycle_rejection("activation_failed"))
	_activation_usec = Time.get_ticks_usec()
	if _prewarm_ready_usec < 0 or _activation_usec < _prewarm_ready_usec:
		return _reject("activation_timeline_invalid")
	return true


func finish_atomic_reveal() -> bool:
	if _phase != PHASE_READY or _lifecycle == null or not _lifecycle.visible:
		return _reject("atomic_reveal_without_active_runtime")
	_loading_host.call("hide_loading")
	_loading_hidden_usec = Time.get_ticks_usec()
	_loading_host.visible = false
	_phase = PHASE_EXTERIOR
	_atomic_reveal_count += 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return true


func tick_exterior(input_direction: Vector2, delta: float, ticks_msec: int) -> Dictionary:
	if _phase != PHASE_EXTERIOR:
		return {"valid": false, "rejection_reason": "production_entry_not_exterior"}
	return _lifecycle.call("tick_exterior", input_direction, delta, ticks_msec) as Dictionary


func try_interact() -> Dictionary:
	if _phase != PHASE_EXTERIOR:
		return {"valid": false, "rejection_reason": "production_entry_not_exterior"}
	return _lifecycle.call("try_interact") as Dictionary


func request_guardian_recall(desired_world_position: Vector2) -> Dictionary:
	if _phase != PHASE_EXTERIOR:
		return {"valid": false, "rejection_reason": "production_entry_not_exterior"}
	return _lifecycle.call("request_guardian_recall", desired_world_position) as Dictionary


func enter_interior(interaction: Dictionary) -> bool:
	if _phase != PHASE_EXTERIOR or not bool(_lifecycle.call("enter_interior", interaction)):
		return false
	_phase = PHASE_INTERIOR
	return true


func return_from_interior(requested_return_world: Variant = null) -> bool:
	if _phase != PHASE_INTERIOR or not bool(_lifecycle.call("return_from_interior", requested_return_world)):
		return false
	_phase = PHASE_EXTERIOR
	return true


func teardown_scene() -> void:
	if _lifecycle != null and is_instance_valid(_lifecycle) and _lifecycle.has_method("teardown_scene"):
		_lifecycle.call("teardown_scene")
	if _loading_host != null and is_instance_valid(_loading_host):
		_loading_host.call("hide_loading")
	visible = false
	_phase = PHASE_TORN_DOWN
	_rejection_reason = "torn_down"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_entry_in_progress() -> bool:
	return _phase in [PHASE_LOADING, PHASE_READY]


func is_rejected() -> bool:
	return _phase == PHASE_REJECTED


func reject_transition(reason: String) -> void:
	if _phase in [PHASE_LOADING, PHASE_READY]:
		_reject(reason if reason != "" else "transition_rejected")


func get_layout_snapshot() -> Dictionary:
	if _lifecycle == null or not _lifecycle.has_method("get_layout_snapshot_for_test"):
		return {}
	return _lifecycle.call("get_layout_snapshot_for_test") as Dictionary


func get_debug_status() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"candidate_only": false,
		"production_connected": true,
		"phase": _phase,
		"rejection_reason": _rejection_reason,
		"progress": _progress,
		"total_update_count": _total_update_count,
		"stalled_update_count": _stalled_update_count,
		"loading_started_usec": _loading_started_usec,
		"loading_first_draw_usec": _loading_first_draw_usec,
		"prewarm_ready_usec": _prewarm_ready_usec,
		"activation_usec": _activation_usec,
		"loading_hidden_usec": _loading_hidden_usec,
		"loading_draw_count": _loading_draw_count,
		"pre_reveal_runtime_visible_count": _pre_reveal_runtime_visible_count,
		"atomic_reveal_count": _atomic_reveal_count,
		"loading_visible": _loading_host != null and _loading_host.visible,
		"lifecycle_visible": _lifecycle != null and _lifecycle.visible,
		"lifecycle": _lifecycle.call("get_debug_status") if _lifecycle != null and _lifecycle.has_method("get_debug_status") else {},
	}


func _ensure_nodes() -> void:
	if _lifecycle == null:
		_lifecycle = _test_lifecycle if _test_lifecycle != null else PlazaR3LifecyclePrewarmCandidate.new()
		_lifecycle.name = "R3Lifecycle"
		_lifecycle.visible = false
		add_child(_lifecycle)
	if _loading_host == null:
		_loading_host = BattleLoadingStainedGlassHost.new()
		_loading_host.name = "R3EntryLoading"
		_loading_host.z_index = 100
		_loading_host.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_loading_host)


func _sync_progress_from_lifecycle(initial: bool) -> void:
	var snapshot: Dictionary = _lifecycle.call("get_prewarm_progress_snapshot")
	var next_progress := clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
	_progress = maxf(_progress, next_progress)
	var token := str(snapshot.get("progress_token", ""))
	if initial or token != _last_progress_token:
		_last_progress_token = token
		_stalled_update_count = 0
	else:
		_stalled_update_count += 1
	_sync_loading_surface("환계도 전개 중", _progress)


func _sync_loading_surface(subtitle: String, next_progress: float) -> void:
	if _loading_host == null:
		return
	_loading_host.call("show_loading", {
		"title": "황역 광장",
		"subtitle": subtitle,
		"tip_tier": BattleLoadingTips.TIER_ADVANCED,
		"tip_character": str(_request.get("selected_character_type", "")),
	}, next_progress, size)


func _lifecycle_rejected() -> bool:
	if _lifecycle == null or not _lifecycle.has_method("get_debug_status"):
		return false
	return str((_lifecycle.call("get_debug_status") as Dictionary).get("phase", "")) == "rejected"


func _lifecycle_rejection(fallback: String) -> String:
	if _lifecycle == null or not _lifecycle.has_method("get_debug_status"):
		return fallback
	var reason := str((_lifecycle.call("get_debug_status") as Dictionary).get("rejection_reason", ""))
	return reason if reason != "" else fallback


func _reject(reason: String) -> bool:
	_rejection_reason = reason
	_phase = PHASE_REJECTED
	_progress = minf(_progress, 0.99)
	_sync_loading_surface("전환 실패: %s" % reason, _progress)
	queue_redraw()
	return false
