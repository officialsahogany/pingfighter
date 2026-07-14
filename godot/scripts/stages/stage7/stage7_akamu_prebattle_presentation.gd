extends RefCounted

const Stage7AkamuPrebattleOverlayHost := preload("res://scripts/stages/stage7/stage7_akamu_prebattle_overlay_host.gd")

const STAGE_ID := 7
const GAME_WIDTH := 760.0
const GAME_HEIGHT := 750.0
const VIDEO_PATH := "res://assets/video/stage7_akamu_intro_v1.ogv"
const VIDEO_DURATION_FALLBACK_SECONDS := 11.50
const VIDEO_FADE_SECONDS := 0.50
const VIDEO_THREAD_LOAD_MAX_MSEC := 5000
const VIDEO_THREAD_LOAD_MAX_POLLS := 600

const PHASE_IDLE := "idle"
const PHASE_LOADING := "loading"
const PHASE_VIDEO := "video"
const PHASE_FADE := "fade"
const PHASE_COMPLETE := "complete"

var _phase := PHASE_IDLE
var _entry_armed := false
var _video_completed_for_entry := false
var _video_elapsed := 0.0
var _fade_elapsed := 0.0
var _completion_reason := ""

var _video_stream: VideoStream = null
var _video_load_requested := false
var _video_load_failed := false
var _video_load_started_msec := 0
var _video_load_poll_count := 0
var _missing_warning_emitted := false
var _host: Control = null


func prewarm_assets_step() -> bool:
	if _video_stream != null or _video_load_failed:
		return true
	if not FileAccess.file_exists(VIDEO_PATH) and not ResourceLoader.exists(VIDEO_PATH):
		_mark_video_load_failed("Stage 7 아카무 리고 인트로 영상이 없습니다: %s" % VIDEO_PATH)
		return true
	if not _video_load_requested:
		var request_error := ResourceLoader.load_threaded_request(VIDEO_PATH, "", true)
		if request_error != OK and request_error != ERR_BUSY:
			_mark_video_load_failed(
				"Stage 7 아카무 리고 인트로 영상의 비동기 로드 요청에 실패해 이번 진입에서는 생략합니다: %s (오류 %d)"
				% [VIDEO_PATH, request_error]
			)
			return true
		_video_load_requested = true
		_video_load_started_msec = Time.get_ticks_msec()
		_video_load_poll_count = 0
		return false

	var status := ResourceLoader.load_threaded_get_status(VIDEO_PATH)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_video_load_poll_count += 1
			if _is_video_thread_load_expired():
				_mark_video_load_failed("Stage 7 아카무 리고 인트로 영상 로딩이 지연되어 이번 진입에서는 생략합니다: %s" % VIDEO_PATH)
				return true
			return false
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(VIDEO_PATH)
			if resource is VideoStream:
				_video_stream = resource as VideoStream
				_clear_video_load_tracking()
			else:
				_mark_video_load_failed("Stage 7 인트로 자원이 VideoStream이 아닙니다: %s" % VIDEO_PATH)
			return true
		_:
			_mark_video_load_failed(
				"Stage 7 아카무 리고 인트로 영상의 비동기 로드에 실패해 이번 진입에서는 생략합니다: %s (상태 %d)"
				% [VIDEO_PATH, int(status)]
			)
			return true


func prewarm_stage_entry_step(owner: Object) -> bool:
	if not prewarm_assets_step():
		return false
	return prewarm_runtime_nodes_step(owner)


func is_video_thread_load_in_flight() -> bool:
	# 부트 웜업의 frame-gated 게이트용: 스레드 영상 로드가 진행 중이면 true.
	# 이 계약이 없으면 budgeted 웜업 루프가 같은 스텝을 프레임당 최대 128회
	# 폴링해 600-poll 탈출구가 ~5프레임 만에 소진된다(냉부트 위양 실패).
	return _video_load_requested and _video_stream == null and not _video_load_failed


func prewarm_runtime_nodes_step(owner: Object) -> bool:
	var host := _ensure_host(owner)
	if host == null:
		return true
	host.set_inactive()
	_sync_host_layout(owner, null)
	return true


func begin_video(owner: Object, registry: Object) -> bool:
	var stage_id := _get_current_stage(owner)
	if stage_id != STAGE_ID:
		if _entry_armed:
			reset_for_stage_entry(stage_id)
		return false
	_ensure_entry(stage_id)
	if _video_completed_for_entry or _phase == PHASE_COMPLETE:
		return false
	if _phase == PHASE_VIDEO or _phase == PHASE_FADE:
		return true
	if not prewarm_stage_entry_step(owner):
		_phase = PHASE_LOADING
		return true
	return _start_loaded_video(owner, registry)


func update(delta: float, owner: Object, registry: Object) -> void:
	if not _entry_armed or _video_completed_for_entry:
		return
	_sync_host_layout(owner, registry)
	match _phase:
		PHASE_LOADING:
			if prewarm_stage_entry_step(owner):
				_start_loaded_video(owner, registry)
		PHASE_VIDEO:
			_video_elapsed += maxf(0.0, delta)
			_sync_video_host(registry, 0.0)
			if _host_video_finished():
				_begin_fade("natural")
			elif _video_elapsed >= VIDEO_DURATION_FALLBACK_SECONDS:
				_begin_fade("duration_fallback")
		PHASE_FADE:
			_fade_elapsed += maxf(0.0, delta)
			var fade_alpha := clampf(_fade_elapsed / VIDEO_FADE_SECONDS, 0.0, 1.0)
			_sync_video_host(registry, fade_alpha)
			if _fade_elapsed >= VIDEO_FADE_SECONDS:
				_finish_video()


func handle_input(event: InputEvent, _owner: Object, _registry: Object) -> bool:
	if _phase != PHASE_VIDEO:
		return false
	if not _is_skip_pressed(event):
		return false
	_begin_fade("skip")
	return true


func is_active() -> bool:
	return _phase == PHASE_LOADING or _phase == PHASE_VIDEO or _phase == PHASE_FADE


func is_video_active() -> bool:
	return _phase == PHASE_VIDEO or _phase == PHASE_FADE


func blocks_battle_physics() -> bool:
	return _entry_armed and not _video_completed_for_entry


func has_pending_work() -> bool:
	return blocks_battle_physics()


func get_phase() -> String:
	return _phase


func get_completion_reason() -> String:
	return _completion_reason


func was_video_completed_for_entry() -> bool:
	return _video_completed_for_entry


func get_asset_status() -> Dictionary:
	return {
		"video_path": VIDEO_PATH,
		"video_loaded": _video_stream != null,
		"video_load_failed": _video_load_failed,
		"host_ready": _host != null and is_instance_valid(_host),
	}


func get_host_for_test() -> Control:
	return _host if _host != null and is_instance_valid(_host) else null


func reset_for_stage_entry(stage_id: int) -> void:
	_stop_and_hide_host()
	_entry_armed = stage_id == STAGE_ID
	_video_completed_for_entry = false
	_video_elapsed = 0.0
	_fade_elapsed = 0.0
	_completion_reason = ""
	_phase = PHASE_IDLE


func reset_for_result() -> void:
	_stop_and_hide_host()
	_entry_armed = false
	_video_completed_for_entry = true
	_completion_reason = "result"
	_phase = PHASE_COMPLETE


func reset() -> void:
	_stop_and_hide_host()
	# A failed load degrades only the entry that observed it. Generic match /
	# stage reset runs before the next entry's prewarm, so it is the safe retry
	# boundary; reset_for_stage_entry() can run after current-entry prewarm and
	# must not trigger a second request in that same entry.
	if _video_stream == null and _video_load_failed:
		_video_load_failed = false
		_missing_warning_emitted = false
	_entry_armed = false
	_video_completed_for_entry = false
	_video_elapsed = 0.0
	_fade_elapsed = 0.0
	_completion_reason = ""
	_phase = PHASE_IDLE


func tear_down() -> void:
	if _host != null and is_instance_valid(_host):
		_host.tear_down(true)
	_host = null
	_entry_armed = false
	_video_completed_for_entry = true
	_completion_reason = "teardown"
	_phase = PHASE_COMPLETE


func _start_loaded_video(owner: Object, registry: Object) -> bool:
	if _video_stream == null:
		_video_completed_for_entry = true
		_completion_reason = "load_failed"
		_phase = PHASE_COMPLETE
		_stop_and_hide_host()
		return false
	var host := _ensure_host(owner)
	if host == null:
		_video_completed_for_entry = true
		_completion_reason = "host_unavailable"
		_phase = PHASE_COMPLETE
		return false
	_stop_battle_bgm(registry)
	_sync_host_layout(owner, registry)
	if not bool(host.begin_video(_video_stream, _is_bgm_muted(registry))):
		_video_completed_for_entry = true
		_completion_reason = "host_start_failed"
		_phase = PHASE_COMPLETE
		return false
	_video_elapsed = 0.0
	_fade_elapsed = 0.0
	_completion_reason = ""
	_phase = PHASE_VIDEO
	return true


func _begin_fade(reason: String) -> void:
	if _phase != PHASE_VIDEO:
		return
	_fade_elapsed = 0.0
	_completion_reason = reason
	_phase = PHASE_FADE


func _finish_video() -> void:
	_stop_and_hide_host()
	_video_completed_for_entry = true
	_phase = PHASE_COMPLETE


func _sync_video_host(registry: Object, fade_alpha: float) -> void:
	if _host != null and is_instance_valid(_host):
		_host.sync_video(_video_elapsed, fade_alpha, _is_bgm_muted(registry))


func _host_video_finished() -> bool:
	return (
		_host != null
		and is_instance_valid(_host)
		and _host.has_method("is_video_finished")
		and bool(_host.is_video_finished())
	)


func _ensure_entry(stage_id: int) -> void:
	if _entry_armed:
		return
	reset_for_stage_entry(stage_id)


func _ensure_host(owner: Object) -> Control:
	if _host != null and is_instance_valid(_host):
		return _host
	_host = null
	if not (owner is Node):
		return null
	var host: Control = Stage7AkamuPrebattleOverlayHost.new()
	(owner as Node).add_child(host)
	host.set_inactive()
	_host = host
	return _host


func _sync_host_layout(owner: Object, registry: Object) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var view_size := _get_view_size(owner)
	var game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	var game_offset := (view_size - game_size) * 0.5
	var view_layout: Object = _get_instance(registry, "battle_view_layout")
	if view_layout != null and view_layout.has_method("build_game_layout"):
		var layout: Dictionary = view_layout.build_game_layout(view_size, GAME_WIDTH, GAME_HEIGHT)
		game_size = _get_vector2(layout.get("game_size", game_size), game_size)
		game_offset = _get_vector2(layout.get("game_offset", game_offset), game_offset)
	_host.sync_layout(view_size, game_offset, game_size)


func _stop_and_hide_host() -> void:
	if _host != null and is_instance_valid(_host):
		_host.set_inactive()


func _stop_battle_bgm(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("stop_bgm"):
		audio.stop_bgm()


func _is_bgm_muted(registry: Object) -> bool:
	var audio: Object = _get_instance(registry, "game_audio")
	return audio != null and audio.has_method("is_bgm_muted") and bool(audio.is_bgm_muted())


func _mark_video_load_failed(message: String) -> void:
	_video_load_failed = true
	_clear_video_load_tracking()
	if not _missing_warning_emitted:
		_missing_warning_emitted = true
		push_warning(message)


func _is_video_thread_load_expired() -> bool:
	if not _video_load_requested:
		return false
	if VIDEO_THREAD_LOAD_MAX_POLLS > 0 and _video_load_poll_count >= VIDEO_THREAD_LOAD_MAX_POLLS:
		return true
	if VIDEO_THREAD_LOAD_MAX_MSEC <= 0 or _video_load_started_msec <= 0:
		return false
	return Time.get_ticks_msec() - _video_load_started_msec >= VIDEO_THREAD_LOAD_MAX_MSEC


func _clear_video_load_tracking() -> void:
	_video_load_requested = false
	_video_load_started_msec = 0
	_video_load_poll_count = 0


func _is_skip_pressed(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return (
			key_event.pressed
			and not key_event.echo
			and (
				key_event.keycode == KEY_SPACE
				or key_event.physical_keycode == KEY_SPACE
				or key_event.keycode == KEY_ENTER
			)
		)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_A
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _get_current_stage(owner: Object) -> int:
	if owner != null:
		var value: Variant = owner.get("current_stage")
		if value != null:
			return int(value)
	return 1


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	if owner != null and owner.has_method("get_viewport"):
		var viewport: Viewport = owner.get_viewport()
		if viewport != null:
			return viewport.get_visible_rect().size
	return Vector2(GAME_WIDTH, GAME_HEIGHT)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value as Vector2 if value is Vector2 else fallback
