extends RefCounted

# Product frame lane for victory highlights. The authoritative/state recorder
# remains active in parallel; every failure here therefore fails closed to the
# existing state replay instead of blocking the victory flow.

const VictoryHighlightRecorder := preload("res://scripts/core/victory_highlight_recorder.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const CAPTURE_SIZE := Vector2i(760, 750)
const MAX_CAPTURE_HZ := 72.0
const CAPTURE_FPS := MAX_CAPTURE_HZ
const MAX_RECORD_SEC := 2.0
const MAX_ACTION_SEC := VictoryHighlightRecorder.MAX_ACTION_SEC
const GOAL_HOLD_SEC := VictoryHighlightRecorder.GOAL_HOLD_SEC
const MAX_CLIP_SEC := VictoryHighlightRecorder.MAX_CLIP_SEC
const CAPTURE_BYTE_COUNT := CAPTURE_SIZE.x * CAPTURE_SIZE.y * 4
const RING_SLOT_COUNT := int(MAX_RECORD_SEC * MAX_CAPTURE_HZ)
const MAX_CLIP_FRAME_COUNT := int(floor(MAX_ACTION_SEC * CAPTURE_FPS))
const MAX_RETAINED_CLIP_COUNT := 3
const LOGICAL_MAX_FRAME_COUNT := RING_SLOT_COUNT + MAX_CLIP_FRAME_COUNT * MAX_RETAINED_CLIP_COUNT
const LOGICAL_MAX_BYTE_COUNT := LOGICAL_MAX_FRAME_COUNT * CAPTURE_BYTE_COUNT
const MAX_IN_FLIGHT := 2
const FRAME_DEADLINE_USEC := int(floor(1_000_000.0 / MAX_CAPTURE_HZ))
const CONSECUTIVE_CAPTURE_FAILURE_THRESHOLD := 3
const FAILURE_REASON_ASYNC_CAPTURE_ERROR := "async_capture_error"
const FAILURE_REASON_BYTE_SIZE_MISMATCH := "byte_size_mismatch"
const FAILURE_REASON_CROP_SYNC_FAILURE := "crop_sync_failure"
const ARM_RESULT_NOT_ARMED := 0
const ARM_RESULT_ARMED := 1
const ARM_RESULT_RETRY := 2
const DEBUG_CAPTURE_ARG := "--victory-highlight-frame-capture-debug"
const DEBUG_CAPTURE_PNG_PATH := "user://victory_highlight_frame_capture_debug.png"
const NORMALIZED_CROP_SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 crop_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec2 source_uv = crop_uv_rect.xy + UV * crop_uv_rect.zw;
	COLOR = texture(TEXTURE, source_uv);
}
"""

var _root_viewport: Viewport = null
var _blit_viewport: SubViewport = null
var _blit_rect: TextureRect = null
var _blit_material: ShaderMaterial = null
var _crop_uv_rect := Rect2(Vector2.ZERO, Vector2.ONE)
var _rd: RenderingDevice = null
var _source_rd_texture := RID()
var _capture_data_format := RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM

var _ring_frames: Array[PackedByteArray] = []
var _ring_times := PackedFloat64Array()
var _ring_write_index := 0
var _ring_count := 0
var _frame_clips_by_id: Dictionary = {}
var _retained_clip_ids: Array[int] = []

var _pending_capture: Dictionary = {}
var _queued_goal: Dictionary = {}
var _in_flight := 0
var _in_flight_high_water := 0
var _capture_epoch := 1
var _next_capture_sec := -INF
var _capture_due_count := 0
var _capture_armed_count := 0
var _capture_produced_count := 0
var _capture_dropped_count := 0
var _capture_work_worst_usec := 0
var _capture_deadline_miss_count := 0
var _recording_enabled := true
var _prewarm_started := false
var _prewarm_draw_seen := false
var _ready := false
var _failed := false
var _forced_startup_failure := false
var _forced_runtime_failure := false
var _forced_crop_sync_failure_once := false
var _forced_viewport_degeneracy_once := false
var _capture_failure_count := 0
var _consecutive_capture_failure_count := 0
var _viewport_retry_count := 0
var _last_capture_failure_reason := ""
var _last_capture_failure_detail := ""
var _fallback_reason := ""
var _last_failure_log := ""
var _last_recovery_log := ""
var _debug_capture_enabled := false
var _debug_arm_logged := false
var _debug_post_draw_logged := false
var _debug_png_dumped := false
var _prewarm_capture_armed := false


func _init() -> void:
	_debug_capture_enabled = OS.get_cmdline_user_args().has(DEBUG_CAPTURE_ARG)
	_ring_frames.resize(RING_SLOT_COUNT)
	_ring_times.resize(RING_SLOT_COUNT)
	for index in range(RING_SLOT_COUNT):
		_ring_frames[index] = PackedByteArray()
		_ring_times[index] = -INF


func prewarm_step(owner: Object) -> bool:
	if _ready or _failed:
		return true
	if _forced_startup_failure:
		_fail_startup("forced_startup_failure", "test injection")
		return true
	if not _prewarm_started:
		if owner == null or not owner.has_method("get_viewport"):
			_fail_startup("owner_unavailable", "owner has no viewport bridge")
			return true
		var viewport_value: Variant = owner.get_viewport()
		if not (viewport_value is Viewport):
			_fail_startup("viewport_unavailable", "owner returned no Viewport")
			return true
		_root_viewport = viewport_value as Viewport
		_rd = RenderingServer.get_rendering_device()
		if _rd == null:
			_fail_startup("rendering_device_unavailable", "RenderingServer returned no device")
			return true
		_build_blit_viewport()
		_connect_frame_signal()
		_prewarm_started = true
	if not _prewarm_draw_seen:
		if not _prewarm_capture_armed:
			var crop_sync := _sync_blit_crop()
			if bool(crop_sync.get("retry", false)):
				_record_viewport_retry("startup", str(crop_sync.get("detail", "viewport temporarily unavailable")))
				return false
			if not bool(crop_sync.get("synced", false)):
				_fail_startup(
					FAILURE_REASON_CROP_SYNC_FAILURE,
					str(crop_sync.get("detail", "prewarm crop synchronization failed"))
				)
				return true
			_blit_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			_prewarm_capture_armed = true
		return false
	var source_texture := RenderingServer.viewport_get_texture(_blit_viewport.get_viewport_rid())
	_source_rd_texture = RenderingServer.texture_get_rd_texture(source_texture, false)
	if not _source_rd_texture.is_valid():
		_fail_startup("source_texture_unavailable", "blit texture has no RenderingDevice RID")
		return true
	var source_format: RDTextureFormat = _rd.texture_get_format(_source_rd_texture)
	if source_format.width != CAPTURE_SIZE.x or source_format.height != CAPTURE_SIZE.y:
		_fail_startup(
			"capture_size_mismatch",
			"actual=%dx%d expected=%dx%d" % [
				source_format.width,
				source_format.height,
				CAPTURE_SIZE.x,
				CAPTURE_SIZE.y,
			]
		)
		return true
	_capture_data_format = source_format.format
	_ready = true
	_recording_enabled = true
	return true


func capture_visual(logical_time_sec: float) -> bool:
	if not _ready or _failed or not _recording_enabled:
		return false
	if not _consume_capture_schedule(logical_time_sec):
		return false
	_capture_due_count += 1
	if not _pending_capture.is_empty() or _in_flight >= MAX_IN_FLIGHT:
		_capture_dropped_count += 1
		return false
	var arm_result := _arm_capture(logical_time_sec, {})
	if arm_result != ARM_RESULT_ARMED:
		return false
	_capture_armed_count += 1
	return true


func request_goal_capture(state_clip: Dictionary, retained_clip_ids: Array[int]) -> bool:
	if not _ready or _failed or state_clip.is_empty():
		return false
	_replace_retained_clip_ids(retained_clip_ids)
	_prune_frame_clips()
	_queued_goal = {
		"clip_id": int(state_clip.get("id", -1)),
		"goal_sec": float(state_clip.get("capture_time_sec", 0.0)),
		"goal_t_sec": float(state_clip.get("goal_t_sec", 0.0)),
		"duration_sec": float(state_clip.get("duration_sec", 0.0)),
		"is_final": bool(state_clip.get("is_final", false)),
	}
	_arm_queued_goal_if_possible()
	return true


func attach_frame_payloads(selected_clips: Array[Dictionary]) -> bool:
	if selected_clips.is_empty():
		return false
	var attached_any := false
	for clip in selected_clips:
		var clip_id := int(clip.get("id", -1))
		if not _frame_clips_by_id.has(clip_id):
			clip.erase("frame_frames")
			clip.erase("frame_size")
			clip.erase("frame_fps")
			clip.erase("frame_data_format")
			continue
		var payload: Dictionary = _frame_clips_by_id[clip_id]
		clip["frame_frames"] = payload.get("frames", [])
		clip["frame_size"] = CAPTURE_SIZE
		clip["frame_fps"] = CAPTURE_FPS
		clip["frame_data_format"] = _capture_data_format
		attached_any = true
	return attached_any


func release_match_clips() -> void:
	release_all()


func reset() -> void:
	release_all()
	_failed = false
	_forced_startup_failure = false
	_forced_runtime_failure = false
	_forced_crop_sync_failure_once = false
	_forced_viewport_degeneracy_once = false


func release_all(
	preserve_failure_diagnostics: bool = false,
	preserve_promoted_clips: bool = false
) -> void:
	_capture_epoch += 1
	_recording_enabled = false
	_pending_capture.clear()
	_queued_goal.clear()
	_in_flight = 0
	_disconnect_frame_signal()
	if _blit_viewport != null and is_instance_valid(_blit_viewport):
		_blit_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# 씬 전환(F10 부스 리셋) 프레임에는 부모인 루트 뷰포트가 자식 처리
		# 중이라 remove_child()가 거부되고, 그 상태의 free()는 부모 자식
		# 목록에 매달린 포인터를 남겨 다음 씬 진입이 얼어붙는다.
		# 트리에 붙어 있으면 항상 queue_free()로 지연 해제한다.
		if _blit_viewport.get_parent() != null:
			_blit_viewport.queue_free()
		else:
			_blit_viewport.free()
	_blit_viewport = null
	_blit_rect = null
	_blit_material = null
	_root_viewport = null
	_source_rd_texture = RID()
	_rd = null
	_ready = false
	_prewarm_started = false
	_prewarm_draw_seen = false
	_prewarm_capture_armed = false
	_next_capture_sec = -INF
	_reset_capture_metrics()
	_crop_uv_rect = Rect2(Vector2.ZERO, Vector2.ONE)
	_debug_arm_logged = false
	_debug_post_draw_logged = false
	_debug_png_dumped = false
	_clear_frame_storage(preserve_promoted_clips)
	if not preserve_failure_diagnostics:
		_reset_failure_diagnostics()


func force_startup_failure_for_tests(value: bool) -> void:
	_forced_startup_failure = value


func force_runtime_failure_for_tests() -> void:
	_forced_runtime_failure = true
	while not _failed:
		_register_capture_failure(
			FAILURE_REASON_ASYNC_CAPTURE_ERROR,
			"forced runtime fallback",
			{}
		)


func force_async_capture_error_for_tests() -> void:
	_in_flight += 1
	_accept_async_error(
		{"epoch": _capture_epoch, "goal_descriptor": {}},
		"forced asynchronous readback error"
	)


func force_byte_size_mismatch_for_tests() -> void:
	_in_flight += 1
	_accept_async_result(
		PackedByteArray(),
		{"epoch": _capture_epoch, "logical_time_sec": 0.0, "goal_descriptor": {}}
	)


func force_crop_sync_failure_for_tests() -> void:
	_forced_crop_sync_failure_once = true
	_arm_capture(0.0, {})


func force_viewport_degeneracy_for_tests() -> void:
	_forced_viewport_degeneracy_once = true
	_arm_capture(0.0, {})


func force_capture_success_for_tests(bytes: PackedByteArray, logical_time_sec: float) -> void:
	_in_flight += 1
	_accept_async_result(
		bytes,
		{"epoch": _capture_epoch, "logical_time_sec": logical_time_sec, "goal_descriptor": {}}
	)


func install_frame_clip_for_tests(clip_id: int, frames: Array[PackedByteArray]) -> void:
	_frame_clips_by_id[clip_id] = {"frames": frames}


func install_owned_viewport_for_tests(parent: Node) -> void:
	_blit_viewport = SubViewport.new()
	_blit_viewport.size = CAPTURE_SIZE
	parent.add_child(_blit_viewport)
	_ready = true


func store_frame_for_tests(bytes: PackedByteArray, logical_time_sec: float) -> void:
	_store_ring_frame(bytes, logical_time_sec)


func promote_goal_for_tests(descriptor: Dictionary, retained_clip_ids: Array[int]) -> void:
	_replace_retained_clip_ids(retained_clip_ids)
	_promote_frame_clip(descriptor)


func consume_capture_schedule_for_tests(logical_time_sec: float) -> bool:
	return _consume_capture_schedule(logical_time_sec)


func get_debug_snapshot() -> Dictionary:
	return {
		"ready": _ready,
		"failed": _failed,
		"ring_count": _ring_count,
		"frame_clip_count": _frame_clips_by_id.size(),
		"in_flight": _in_flight,
		"in_flight_high_water": _in_flight_high_water,
		"pending_capture": not _pending_capture.is_empty(),
		"queued_goal": not _queued_goal.is_empty(),
		"capture_due_count": _capture_due_count,
		"capture_armed_count": _capture_armed_count,
		"capture_produced_count": _capture_produced_count,
		"capture_dropped_count": _capture_dropped_count,
		"capture_work_worst_usec": _capture_work_worst_usec,
		"capture_deadline_miss_count": _capture_deadline_miss_count,
		"capture_failure_count": _capture_failure_count,
		"consecutive_capture_failure_count": _consecutive_capture_failure_count,
		"viewport_retry_count": _viewport_retry_count,
		"failure_threshold": CONSECUTIVE_CAPTURE_FAILURE_THRESHOLD,
		"last_capture_failure_reason": _last_capture_failure_reason,
		"last_capture_failure_detail": _last_capture_failure_detail,
		"fallback_reason": _fallback_reason,
		"last_failure_log": _last_failure_log,
		"last_recovery_log": _last_recovery_log,
		"owned_rid_count": 1 if _blit_viewport != null and is_instance_valid(_blit_viewport) else 0,
		"capture_backend": "normalized_uv",
		"crop_uv_rect": _crop_uv_rect,
	}


func get_latest_frame_for_tests() -> PackedByteArray:
	if _ring_count <= 0:
		return PackedByteArray()
	var slot := (_ring_write_index - 1 + RING_SLOT_COUNT) % RING_SLOT_COUNT
	return _ring_frames[slot].duplicate()


func is_available() -> bool:
	return _ready and not _failed


func _build_blit_viewport() -> void:
	_blit_viewport = SubViewport.new()
	_blit_viewport.name = "VictoryHighlightProductBlitViewport"
	_blit_viewport.size = CAPTURE_SIZE
	_blit_viewport.disable_3d = true
	_blit_viewport.transparent_bg = false
	_blit_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_blit_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_root_viewport.add_child(_blit_viewport)
	_blit_rect = TextureRect.new()
	_blit_rect.name = "VictoryHighlightRootGameRectBlit"
	_blit_rect.position = Vector2.ZERO
	_blit_rect.size = Vector2(CAPTURE_SIZE)
	_blit_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_blit_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_blit_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_blit_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blit_material = ShaderMaterial.new()
	var crop_shader := Shader.new()
	crop_shader.code = NORMALIZED_CROP_SHADER_CODE
	_blit_material.shader = crop_shader
	_blit_rect.material = _blit_material
	_blit_rect.texture = _root_viewport.get_texture()
	_blit_viewport.add_child(_blit_rect)


func _connect_frame_signal() -> void:
	var callback := Callable(self, "_on_frame_post_draw")
	if not RenderingServer.frame_post_draw.is_connected(callback):
		RenderingServer.frame_post_draw.connect(callback)


func _disconnect_frame_signal() -> void:
	var callback := Callable(self, "_on_frame_post_draw")
	if RenderingServer.frame_post_draw.is_connected(callback):
		RenderingServer.frame_post_draw.disconnect(callback)


func _arm_capture(logical_time_sec: float, goal_descriptor: Dictionary) -> int:
	if not _ready or _failed or _blit_viewport == null:
		return ARM_RESULT_NOT_ARMED
	var crop_sync := _sync_blit_crop()
	if _forced_crop_sync_failure_once:
		_forced_crop_sync_failure_once = false
		crop_sync = {
			"synced": false,
			"retry": false,
			"detail": "normalized game crop synchronization failed",
		}
	if _forced_viewport_degeneracy_once:
		_forced_viewport_degeneracy_once = false
		crop_sync = {
			"synced": false,
			"retry": true,
			"detail": "forced viewport degeneracy",
		}
	if bool(crop_sync.get("retry", false)):
		_record_viewport_retry("runtime", str(crop_sync.get("detail", "viewport temporarily unavailable")))
		return ARM_RESULT_RETRY
	if not bool(crop_sync.get("synced", false)):
		_register_capture_failure(
			FAILURE_REASON_CROP_SYNC_FAILURE,
			str(crop_sync.get("detail", "normalized game crop synchronization failed")),
			goal_descriptor
		)
		return ARM_RESULT_NOT_ARMED
	_pending_capture = {
		"epoch": _capture_epoch,
		"logical_time_sec": logical_time_sec,
		"goal_descriptor": goal_descriptor.duplicate(),
	}
	_maybe_log_capture_geometry("arm")
	_blit_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return ARM_RESULT_ARMED


func _on_frame_post_draw() -> void:
	if _prewarm_started and not _ready and not _prewarm_draw_seen:
		# A transiently degenerate root viewport never armed the prewarm draw.
		# Ignore this unrelated frame signal so the next prewarm_step can retry.
		if not _prewarm_capture_armed:
			return
		_prewarm_draw_seen = true
		_prewarm_capture_armed = false
		if _blit_viewport != null:
			_blit_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if _pending_capture.is_empty() or _blit_viewport == null:
		return
	_maybe_log_capture_geometry("post_draw")
	_blit_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var request := _pending_capture.duplicate(true)
	_pending_capture.clear()
	request["source"] = _source_rd_texture
	request.make_read_only()
	_in_flight += 1
	_in_flight_high_water = maxi(_in_flight_high_water, _in_flight)
	RenderingServer.call_on_render_thread(Callable(self, "_submit_async_readback").bind(request))


func _submit_async_readback(request: Dictionary) -> void:
	var work_start_usec := Time.get_ticks_usec()
	if _rd == null or _forced_runtime_failure:
		Callable(self, "_accept_capture_work_metric").call_deferred(
			int(Time.get_ticks_usec() - work_start_usec)
		)
		Callable(self, "_accept_async_error").call_deferred(
			request,
			"RenderingDevice unavailable or forced failure"
		)
		return
	var source: RID = request.get("source", RID())
	if not source.is_valid():
		Callable(self, "_accept_capture_work_metric").call_deferred(
			int(Time.get_ticks_usec() - work_start_usec)
		)
		Callable(self, "_accept_async_error").call_deferred(request, "source texture RID invalid")
		return
	var callback := Callable(self, "_on_async_bytes_ready").bind(request)
	var error := _rd.texture_get_data_async(source, 0, callback)
	Callable(self, "_accept_capture_work_metric").call_deferred(
		int(Time.get_ticks_usec() - work_start_usec)
	)
	if error != OK:
		Callable(self, "_accept_async_error").call_deferred(
			request,
			"texture_get_data_async returned %s" % error_string(error)
		)


func _on_async_bytes_ready(bytes: PackedByteArray, request: Dictionary) -> void:
	Callable(self, "_accept_async_result").call_deferred(bytes, request)


func _accept_async_error(request: Dictionary, detail: String = "asynchronous readback callback failed") -> void:
	_in_flight = maxi(0, _in_flight - 1)
	if int(request.get("epoch", -1)) != _capture_epoch:
		return
	_register_capture_failure(
		FAILURE_REASON_ASYNC_CAPTURE_ERROR,
		detail,
		request.get("goal_descriptor", {})
	)


func _accept_async_result(bytes: PackedByteArray, request: Dictionary) -> void:
	var work_start_usec := Time.get_ticks_usec()
	_in_flight = maxi(0, _in_flight - 1)
	if int(request.get("epoch", -1)) != _capture_epoch:
		_accept_capture_work_metric(int(Time.get_ticks_usec() - work_start_usec))
		return
	if bytes.size() != CAPTURE_BYTE_COUNT:
		_accept_capture_work_metric(int(Time.get_ticks_usec() - work_start_usec))
		_register_capture_failure(
			FAILURE_REASON_BYTE_SIZE_MISMATCH,
			"actual=%d expected=%d" % [bytes.size(), CAPTURE_BYTE_COUNT],
			request.get("goal_descriptor", {})
		)
		return
	_record_capture_success()
	_maybe_dump_debug_frame(bytes)
	_store_ring_frame(bytes, float(request.get("logical_time_sec", 0.0)))
	_capture_produced_count += 1
	var goal_descriptor: Dictionary = request.get("goal_descriptor", {})
	if not goal_descriptor.is_empty():
		_promote_frame_clip(goal_descriptor)
		if bool(goal_descriptor.get("is_final", false)):
			_recording_enabled = false
	_arm_queued_goal_if_possible()
	_accept_capture_work_metric(int(Time.get_ticks_usec() - work_start_usec))


func _store_ring_frame(bytes: PackedByteArray, logical_time_sec: float) -> void:
	_ring_frames[_ring_write_index] = bytes
	_ring_times[_ring_write_index] = logical_time_sec
	_ring_write_index = (_ring_write_index + 1) % RING_SLOT_COUNT
	_ring_count = mini(RING_SLOT_COUNT, _ring_count + 1)


func _promote_frame_clip(descriptor: Dictionary) -> void:
	if _ring_count <= 0:
		return
	var clip_id := int(descriptor.get("clip_id", -1))
	if clip_id < 0:
		return
	var duration_sec := clampf(float(descriptor.get("duration_sec", 0.0)), 0.01, MAX_CLIP_SEC)
	var goal_sec := float(descriptor.get("goal_sec", 0.0))
	var goal_t_sec := clampf(
		float(descriptor.get("goal_t_sec", 0.0)),
		0.0,
		minf(duration_sec, MAX_ACTION_SEC)
	)
	var clip_start := goal_sec - goal_t_sec
	var frame_count := mini(
		MAX_CLIP_FRAME_COUNT,
		maxi(1, int(floor(goal_t_sec * CAPTURE_FPS + 0.000001)))
	)
	var ordered_frames: Array[PackedByteArray] = []
	var ordered_times := PackedFloat64Array()
	for offset in range(_ring_count):
		var slot := (_ring_write_index - _ring_count + offset + RING_SLOT_COUNT) % RING_SLOT_COUNT
		if _ring_frames[slot].size() != CAPTURE_BYTE_COUNT:
			continue
		ordered_frames.append(_ring_frames[slot])
		ordered_times.append(_ring_times[slot])
	if ordered_frames.is_empty():
		return
	var frames: Array[PackedByteArray] = []
	frames.resize(frame_count)
	var source_index := 0
	for frame_index in range(frame_count):
		var target_sec := clip_start + goal_t_sec * float(frame_index + 1) / float(frame_count)
		while source_index + 1 < ordered_times.size() and ordered_times[source_index + 1] <= target_sec + 0.000001:
			source_index += 1
		frames[frame_index] = ordered_frames[source_index]
	_frame_clips_by_id[clip_id] = {"frames": frames}
	_prune_frame_clips()


func _arm_queued_goal_if_possible() -> void:
	if _queued_goal.is_empty() or not _ready or _failed:
		return
	if not _pending_capture.is_empty() or _in_flight >= MAX_IN_FLIGHT:
		return
	var descriptor := _queued_goal.duplicate()
	_queued_goal.clear()
	var arm_result := _arm_capture(float(descriptor.get("goal_sec", 0.0)), descriptor)
	if arm_result == ARM_RESULT_RETRY:
		_queued_goal = descriptor


func _prune_frame_clips() -> void:
	for value in _frame_clips_by_id.keys():
		if int(value) not in _retained_clip_ids:
			_frame_clips_by_id.erase(value)


func _replace_retained_clip_ids(retained_clip_ids: Array[int]) -> void:
	_retained_clip_ids.clear()
	for clip_id in retained_clip_ids:
		if _retained_clip_ids.size() >= MAX_RETAINED_CLIP_COUNT:
			break
		if clip_id not in _retained_clip_ids:
			_retained_clip_ids.append(clip_id)


func _consume_capture_schedule(logical_time_sec: float) -> bool:
	if logical_time_sec + 0.000001 < _next_capture_sec:
		return false
	var interval_sec := 1.0 / MAX_CAPTURE_HZ
	if not is_finite(_next_capture_sec) or logical_time_sec - _next_capture_sec >= interval_sec:
		_next_capture_sec = logical_time_sec + interval_sec
	else:
		_next_capture_sec += interval_sec
	return true


func _accept_capture_work_metric(work_usec: int) -> void:
	_capture_work_worst_usec = maxi(_capture_work_worst_usec, work_usec)
	if work_usec > FRAME_DEADLINE_USEC:
		_capture_deadline_miss_count += 1


func _reset_capture_metrics() -> void:
	_in_flight_high_water = 0
	_capture_due_count = 0
	_capture_armed_count = 0
	_capture_produced_count = 0
	_capture_dropped_count = 0
	_capture_work_worst_usec = 0
	_capture_deadline_miss_count = 0


func _sync_blit_crop() -> Dictionary:
	if _root_viewport == null or _blit_rect == null or _blit_material == null:
		return {
			"synced": false,
			"retry": false,
			"detail": "capture crop owners are unavailable",
		}
	var root_texture := _root_viewport.get_texture()
	if root_texture == null:
		return {
			"synced": false,
			"retry": true,
			"detail": "root viewport texture is null",
		}
	var canvas_size := _root_viewport.get_visible_rect().size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return {
			"synced": false,
			"retry": true,
			"detail": "root viewport visible rect is degenerate: %s" % str(canvas_size),
		}
	var crop_uv_rect := _build_normalized_game_uv(canvas_size)
	if not _is_valid_normalized_uv_rect(crop_uv_rect):
		return {
			"synced": false,
			"retry": false,
			"detail": "normalized game crop is invalid: %s" % str(crop_uv_rect),
		}
	# The crop is expressed only in normalized source UVs. Canvas units,
	# framebuffer pixels, and a temporarily stale ViewportTexture size therefore
	# cannot produce an out-of-range absolute AtlasTexture.region.
	_blit_rect.texture = root_texture
	_blit_material.set_shader_parameter(
		"crop_uv_rect",
		Vector4(crop_uv_rect.position.x, crop_uv_rect.position.y, crop_uv_rect.size.x, crop_uv_rect.size.y)
	)
	_crop_uv_rect = crop_uv_rect
	return {"synced": true, "retry": false, "detail": ""}


func _build_normalized_game_uv(view_size: Vector2) -> Rect2:
	var game_rect := _build_game_rect(view_size)
	return Rect2(game_rect.position / view_size, game_rect.size / view_size)


func _is_valid_normalized_uv_rect(crop_uv_rect: Rect2) -> bool:
	var end := crop_uv_rect.end
	return (
		crop_uv_rect.position.x >= 0.0
		and crop_uv_rect.position.y >= 0.0
		and crop_uv_rect.size.x > 0.0
		and crop_uv_rect.size.y > 0.0
		and end.x <= 1.0
		and end.y <= 1.0
		and is_finite(crop_uv_rect.position.x)
		and is_finite(crop_uv_rect.position.y)
		and is_finite(crop_uv_rect.size.x)
		and is_finite(crop_uv_rect.size.y)
	)


func _maybe_log_capture_geometry(phase: String) -> void:
	if not _debug_capture_enabled:
		return
	if phase == "arm":
		if _debug_arm_logged:
			return
		_debug_arm_logged = true
	elif phase == "post_draw":
		if _debug_post_draw_logged:
			return
		_debug_post_draw_logged = true
	var visible_size := _root_viewport.get_visible_rect().size if _root_viewport != null else Vector2.ZERO
	var texture_size := Vector2.ZERO
	if _root_viewport != null and _root_viewport.get_texture() != null:
		texture_size = Vector2(_root_viewport.get_texture().get_size())
	print(
		"victory_highlight_frame_capture_geometry: phase=%s window=%s visible=%s texture=%s uv=%s" % [
			phase,
			str(DisplayServer.window_get_size()).replace(" ", ""),
			str(visible_size).replace(" ", ""),
			str(texture_size).replace(" ", ""),
			str(_crop_uv_rect).replace(" ", ""),
		]
	)


func _maybe_dump_debug_frame(bytes: PackedByteArray) -> void:
	if not _debug_capture_enabled or _debug_png_dumped:
		return
	_debug_png_dumped = true
	var image := Image.create_from_data(
		CAPTURE_SIZE.x,
		CAPTURE_SIZE.y,
		false,
		Image.FORMAT_RGBA8,
		bytes
	)
	var result := image.save_png(DEBUG_CAPTURE_PNG_PATH)
	print(
		"victory_highlight_frame_capture_debug_png: path=%s result=%s" % [
			ProjectSettings.globalize_path(DEBUG_CAPTURE_PNG_PATH),
			error_string(result),
		]
	)


func _build_game_rect(view_size: Vector2) -> Rect2:
	var scale := minf(view_size.x / GAME_SIZE.x, view_size.y / GAME_SIZE.y)
	var size := GAME_SIZE * scale
	return Rect2((view_size - size) * 0.5, size)


func _register_capture_failure(reason: String, detail: String, goal_descriptor: Dictionary) -> void:
	_capture_failure_count += 1
	_consecutive_capture_failure_count += 1
	_last_capture_failure_reason = reason
	_last_capture_failure_detail = detail
	if _consecutive_capture_failure_count >= CONSECUTIVE_CAPTURE_FAILURE_THRESHOLD:
		_fail_runtime(reason, detail)
		return
	_last_failure_log = _build_failure_log("runtime", "recover", reason, detail)
	print(_last_failure_log)
	_recover_goal_descriptor(goal_descriptor)
	_arm_queued_goal_if_possible()


func _record_viewport_retry(phase: String, detail: String) -> void:
	_viewport_retry_count += 1
	if _debug_capture_enabled:
		print(
			"victory_highlight_frame_capture_retry: phase=%s action=skip reason=viewport_degenerate detail=%s retry_count=%d"
			% [phase, detail, _viewport_retry_count]
		)


func _record_capture_success() -> void:
	if _consecutive_capture_failure_count <= 0:
		return
	_last_recovery_log = (
		"victory_highlight_frame_capture_recovery: phase=runtime action=success previous_reason=%s previous_consecutive=%d"
		% [_last_capture_failure_reason, _consecutive_capture_failure_count]
	)
	print(_last_recovery_log)
	_consecutive_capture_failure_count = 0


func _recover_goal_descriptor(goal_descriptor: Dictionary) -> void:
	if goal_descriptor.is_empty():
		return
	_promote_frame_clip(goal_descriptor)
	if bool(goal_descriptor.get("is_final", false)):
		_recording_enabled = false


func _build_failure_log(phase: String, action: String, reason: String, detail: String) -> String:
	var prefix := (
		"victory_highlight_frame_capture_fallback"
		if action == "fallback"
		else "victory_highlight_frame_capture_recovery"
	)
	return (
		"%s: phase=%s action=%s reason=%s detail=%s consecutive=%d threshold=%d total=%d ring_count=%d frame_clip_count=%d"
		% [
			prefix,
			phase,
			action,
			reason,
			detail,
			_consecutive_capture_failure_count,
			CONSECUTIVE_CAPTURE_FAILURE_THRESHOLD,
			_capture_failure_count,
			_ring_count,
			_frame_clips_by_id.size(),
		]
	)


func _fail_startup(reason: String, detail: String) -> void:
	_capture_failure_count += 1
	_consecutive_capture_failure_count = 1
	_last_capture_failure_reason = reason
	_last_capture_failure_detail = detail
	_fallback_reason = reason
	_last_failure_log = _build_failure_log("startup", "fallback", reason, detail)
	print(_last_failure_log)
	_failed = true
	release_all(true)
	_failed = true


func _fail_runtime(reason: String, detail: String) -> void:
	_fallback_reason = reason
	_last_failure_log = _build_failure_log("runtime", "fallback", reason, detail)
	print(_last_failure_log)
	_failed = true
	release_all(true, true)
	_failed = true


func _reset_failure_diagnostics() -> void:
	_capture_failure_count = 0
	_consecutive_capture_failure_count = 0
	_viewport_retry_count = 0
	_last_capture_failure_reason = ""
	_last_capture_failure_detail = ""
	_fallback_reason = ""
	_last_failure_log = ""
	_last_recovery_log = ""


func _clear_frame_storage(preserve_promoted_clips: bool = false) -> void:
	for index in range(RING_SLOT_COUNT):
		_ring_frames[index] = PackedByteArray()
		_ring_times[index] = -INF
	_ring_write_index = 0
	_ring_count = 0
	if not preserve_promoted_clips:
		_frame_clips_by_id.clear()
		_retained_clip_ids.clear()
