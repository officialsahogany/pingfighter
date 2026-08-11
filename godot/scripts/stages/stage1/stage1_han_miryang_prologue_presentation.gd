extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StoryCinematicProgressStore := preload("res://scripts/core/story_cinematic_progress_store.gd")
const PrologueText := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_text.gd")
const PrologueOverlayHost := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_overlay_host.gd")

const CINEMATIC_ID := "han_miryang_araul_first_contest_v2"
const STAGE_ID := 1
const RUNTIME_CHARACTER_ID := "smasher"
const DURATION_SECONDS := 48.0
const SKIP_FADE_SECONDS := 0.45
const FIRST_VIEW_SKIP_LOCK_SECONDS := 1.2
const NATURAL_FADE_START_SECONDS := 47.5

const BGM_DUCK_START := 11.2
const BGM_DUCK_END := 12.6
const BGM_DUCK_GAIN_DB := -10.0
const BGM_SILENCE_FADE_START := 20.8
const BGM_SILENCE_START := 21.6
const BGM_RESTORE_START := 23.4
const BGM_RESTORE_END := 26.5
const BGM_SILENT_GAIN_DB := -80.0
const RAYS_CUE_SECONDS := 27.4
const SPIRIT_BELL_CUE_SECONDS := 33.4

const LIVE_STREAM_MAX_MSEC := 120000
const LIVE_STREAM_MAX_POLLS := 100000
const LIVE_STREAM_ALLOW_SYNC_FALLBACK := false

const A1_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_a1_coronation.png"
const A2_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_a2_tablet.png"
const A3_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_a3_spirit.png"
const B1_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_b1_resistance.png"
const B2_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_b2_orb_extraction.png"
const C1_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_c1_eight_rays.png"
const D1_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_d1_confrontation.png"
const D2_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_prologue_v3_d2_first_strike.png"

const STARTUP_TEXTURE_SPECS := [
	{"key": PrologueOverlayHost.PLATE_A1, "path": A1_TEXTURE_PATH},
	{"key": PrologueOverlayHost.PLATE_A2, "path": A2_TEXTURE_PATH},
	{"key": PrologueOverlayHost.PLATE_A3, "path": A3_TEXTURE_PATH},
]
const STREAM_TEXTURE_SPECS := [
	{"key": PrologueOverlayHost.PLATE_B1, "path": B1_TEXTURE_PATH, "request_at": 0.0, "deadline": 12.0},
	{"key": PrologueOverlayHost.PLATE_B2, "path": B2_TEXTURE_PATH, "request_at": 12.6, "deadline": 20.0},
	{"key": PrologueOverlayHost.PLATE_C1, "path": C1_TEXTURE_PATH, "request_at": 16.2, "deadline": 22.0},
	{"key": PrologueOverlayHost.PLATE_D1, "path": D1_TEXTURE_PATH, "request_at": 19.6, "deadline": 27.0},
	{"key": PrologueOverlayHost.PLATE_D2, "path": D2_TEXTURE_PATH, "request_at": 23.6, "deadline": 30.0},
]
const PLATE_TIMELINE_SPECS := [
	{"key": PrologueOverlayHost.PLATE_A1, "path": A1_TEXTURE_PATH, "replacement_end": 0.0},
	{"key": PrologueOverlayHost.PLATE_A2, "path": A2_TEXTURE_PATH, "replacement_end": 12.6},
	{"key": PrologueOverlayHost.PLATE_A3, "path": A3_TEXTURE_PATH, "replacement_end": 16.2},
	{"key": PrologueOverlayHost.PLATE_B1, "path": B1_TEXTURE_PATH, "replacement_end": 19.6},
	{"key": PrologueOverlayHost.PLATE_B2, "path": B2_TEXTURE_PATH, "replacement_end": 23.6},
	{"key": PrologueOverlayHost.PLATE_C1, "path": C1_TEXTURE_PATH, "replacement_end": 27.4},
	{"key": PrologueOverlayHost.PLATE_D1, "path": D1_TEXTURE_PATH, "replacement_end": 30.8},
	{"key": PrologueOverlayHost.PLATE_D2, "path": D2_TEXTURE_PATH, "replacement_end": 34.0},
]

const PHASE_IDLE := "idle"
const PHASE_LOADING := "loading"
const PHASE_ACTIVE := "active"
const PHASE_SKIP_FADE := "skip_fade"
const PHASE_COMPLETE := "complete"

var _phase := PHASE_IDLE
var _elapsed := 0.0
var _skip_elapsed := 0.0
var _completion_reason := ""
var _startup_prewarm_index := 0
var _stream_index := 0
var _startup_textures: Dictionary = {}
var _stream_textures: Dictionary = {}
var _stream_texture_factory_for_test: Callable
var _stream_deadline_misses: Dictionary = {}
var _released_plate_keys: Dictionary = {}
var _resident_peak := 0
var _host: Control = null
var _segments: Array = []
var _elapsed_segments: Array = []
var _copy: Dictionary = {}
var _progress_store: Object = StoryCinematicProgressStore.new()
var _entry_request_override_for_test: Variant = null
var _skip_lock_seconds := FIRST_VIEW_SKIP_LOCK_SECONDS
var _opening_drum_played := false
var _rays_cue_played := false
var _spirit_bell_cue_played := false
var _a_family_released := false
var _b_family_released := false
var _registry: Object = null


static func get_texture_paths() -> Array[String]:
	var result: Array[String] = []
	for spec_value in STARTUP_TEXTURE_SPECS:
		var spec: Dictionary = spec_value
		result.append(str(spec.get("path", "")))
	return result


static func get_all_texture_paths() -> Array[String]:
	var result := get_texture_paths()
	for spec_value in STREAM_TEXTURE_SPECS:
		var spec: Dictionary = spec_value
		result.append(str(spec.get("path", "")))
	return result


static func is_entry_eligible(stage_id: int, runtime_character_id: String, requested: bool, _seen: bool) -> bool:
	# 캐릭터 선택 화면에서 한미량을 확정한 진입은 감상 이력과 무관하게
	# 매번 재생한다. 재도전/디버그 직행은 transient request가 없으므로 제외된다.
	return stage_id == STAGE_ID and runtime_character_id.strip_edges().to_lower() == RUNTIME_CHARACTER_ID and requested


func should_prewarm_for_entry(owner: Object) -> bool:
	return is_entry_eligible(
		_get_current_stage(owner),
		_get_runtime_character_id(owner),
		_peek_entry_request(owner),
		false
	)


func prewarm_assets_step() -> bool:
	if _startup_prewarm_index >= STARTUP_TEXTURE_SPECS.size():
		return true
	var spec: Dictionary = STARTUP_TEXTURE_SPECS[_startup_prewarm_index]
	var path := str(spec.get("path", ""))
	var result := ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"한미량 프롤로그 이미지가 없습니다: %s",
		"한미량 프롤로그 이미지를 불러오지 못했습니다: %s",
		5000,
		600,
		true,
		true
	)
	if not bool(result.get("done", true)):
		return false
	var texture_value: Variant = result.get("texture", null)
	if texture_value is Texture2D:
		_startup_textures[str(spec.get("key", ""))] = texture_value
	_startup_prewarm_index += 1
	return _startup_prewarm_index >= STARTUP_TEXTURE_SPECS.size()


func prewarm_stage_entry_step(owner: Object) -> bool:
	if not should_prewarm_for_entry(owner):
		return true
	if not prewarm_assets_step():
		return false
	return prewarm_runtime_nodes_step(owner)


func prewarm_runtime_nodes_step(owner: Object) -> bool:
	var host := _ensure_host(owner)
	if host == null:
		return true
	host.set_inactive()
	host.sync_layout(_get_view_size(owner))
	return true


func begin(owner: Object, registry: Object) -> bool:
	_registry = registry
	var requested := _consume_entry_request(owner)
	if not is_entry_eligible(
		_get_current_stage(owner),
		_get_runtime_character_id(owner),
		requested,
		false
	):
		_phase = PHASE_COMPLETE
		_completion_reason = "ineligible"
		return false
	if not prewarm_assets_step():
		_phase = PHASE_LOADING
		return true
	if not prewarm_runtime_nodes_step(owner):
		return _complete_failed_start("host_unavailable")
	return _start(owner)


func update(delta: float, owner: Object, _registry_value: Object) -> void:
	if _phase == PHASE_LOADING:
		if prewarm_assets_step() and prewarm_runtime_nodes_step(owner):
			_start(owner)
		return
	if _phase == PHASE_ACTIVE:
		var previous_elapsed := _elapsed
		_elapsed += maxf(0.0, delta)
		_release_completed_plates()
		_advance_live_streaming()
		_sync_story_audio(previous_elapsed)
		var natural_fade_alpha := _smoothstep(NATURAL_FADE_START_SECONDS, DURATION_SECONDS, _elapsed)
		_sync_host(owner, natural_fade_alpha)
		if _elapsed >= DURATION_SECONDS:
			_finish("natural")
		return
	if _phase == PHASE_SKIP_FADE:
		_skip_elapsed += maxf(0.0, delta)
		var fade_alpha := clampf(_skip_elapsed / SKIP_FADE_SECONDS, 0.0, 1.0)
		_sync_host(owner, fade_alpha)
		if _skip_elapsed >= SKIP_FADE_SECONDS:
			_finish("skip")
		return
	if _phase == PHASE_COMPLETE:
		_stop_and_hide_host()
		return
	_sync_host(owner, 0.0)


func handle_input(event: InputEvent, _owner: Object, _registry_value: Object) -> bool:
	if _phase != PHASE_ACTIVE or _elapsed < _skip_lock_seconds or not _is_skip_pressed(event):
		return false
	_restore_story_audio()
	_skip_elapsed = 0.0
	_completion_reason = "skip"
	_phase = PHASE_SKIP_FADE
	return true


func is_active() -> bool:
	return _phase == PHASE_LOADING or _phase == PHASE_ACTIVE or _phase == PHASE_SKIP_FADE


func blocks_battle_physics() -> bool:
	return is_active()


func has_pending_work() -> bool:
	return is_active()


func get_phase() -> String:
	return _phase


func get_elapsed() -> float:
	return _elapsed


func get_completion_reason() -> String:
	return _completion_reason


func get_skip_lock_seconds() -> float:
	return _skip_lock_seconds


func get_host_for_test() -> Control:
	return _host if _host != null and is_instance_valid(_host) else null


func get_asset_status() -> Dictionary:
	return {
		"startup_ready": _startup_textures.duplicate(),
		"stream_ready": _stream_textures.duplicate(),
		"startup_prewarm_index": _startup_prewarm_index,
		"stream_index": _stream_index,
		"stream_completed_count": _stream_index,
		"deadline_misses": _stream_deadline_misses.duplicate(),
		"released_plate_keys": _released_plate_keys.duplicate(),
		"resident_count": _get_resident_count(),
		"resident_peak": _resident_peak,
		"a_family_released": _a_family_released,
		"b_family_released": _b_family_released,
		"host_ready": _host != null and is_instance_valid(_host),
	}


func set_progress_path_for_test(path: String) -> void:
	_progress_store.set_save_path(path)


func set_entry_request_override_for_test(value: Variant) -> void:
	_entry_request_override_for_test = value


func remove_startup_texture_for_test(plate_key: String) -> void:
	_startup_textures.erase(plate_key)


func seed_startup_textures_for_test(textures: Dictionary) -> void:
	_startup_textures.clear()
	for plate_key_value in textures:
		var texture_value: Variant = textures[plate_key_value]
		if texture_value is Texture2D:
			_startup_textures[str(plate_key_value)] = texture_value
	_startup_prewarm_index = STARTUP_TEXTURE_SPECS.size()


func set_stream_texture_factory_for_test(factory: Callable) -> void:
	_stream_texture_factory_for_test = factory


func tear_down() -> void:
	_restore_story_audio()
	_discard_all_plate_references()
	if _host != null and is_instance_valid(_host):
		_host.tear_down(true)
	_host = null
	_registry = null
	_phase = PHASE_COMPLETE
	_completion_reason = "teardown"


func _start(owner: Object) -> bool:
	for spec_value in STARTUP_TEXTURE_SPECS:
		var spec: Dictionary = spec_value
		if not (_startup_textures.get(str(spec.get("key", "")), null) is Texture2D):
			return _complete_failed_start("asset_unavailable")
	var host := _ensure_host(owner)
	if host == null:
		return _complete_failed_start("host_unavailable")
	var locale := LanguageSettings.get_language()
	_segments = PrologueText.get_segments(locale)
	_elapsed_segments = PrologueText.get_elapsed_segments(locale)
	_copy = PrologueText.get_copy(locale)
	_skip_lock_seconds = 0.0 if _progress_store.has_seen(CINEMATIC_ID) else FIRST_VIEW_SKIP_LOCK_SECONDS
	_elapsed = 0.0
	_skip_elapsed = 0.0
	_stream_index = 0
	_stream_textures.clear()
	_stream_deadline_misses.clear()
	_released_plate_keys.clear()
	_resident_peak = 0
	_opening_drum_played = false
	_rays_cue_played = false
	_spirit_bell_cue_played = false
	_a_family_released = false
	_b_family_released = false
	_completion_reason = ""
	_phase = PHASE_ACTIVE
	host.sync_layout(_get_view_size(owner))
	if not bool(host.begin(_startup_textures, _copy)):
		return _complete_failed_start("host_start_failed")
	_record_resident_count()
	_play_opening_drum()
	_advance_live_streaming()
	_sync_host(owner, 0.0)
	return true


func _complete_failed_start(reason: String) -> bool:
	_restore_story_audio()
	_completion_reason = reason
	_phase = PHASE_COMPLETE
	_stop_and_hide_host()
	_discard_all_plate_references()
	if _host != null and is_instance_valid(_host):
		_host.tear_down(true)
	_host = null
	_registry = null
	return false


func _advance_live_streaming() -> void:
	while _stream_index < STREAM_TEXTURE_SPECS.size():
		var spec: Dictionary = STREAM_TEXTURE_SPECS[_stream_index]
		var plate_key := str(spec.get("key", ""))
		var path := str(spec.get("path", ""))
		var request_at := float(spec.get("request_at", 0.0))
		var deadline := float(spec.get("deadline", 0.0))
		if _elapsed + 0.0001 < request_at:
			return
		if _stream_texture_factory_for_test.is_valid():
			var fixture_result: Variant = _stream_texture_factory_for_test.call(plate_key, _elapsed)
			if fixture_result is Dictionary:
				var fixture_status: Dictionary = fixture_result
				if not bool(fixture_status.get("done", true)):
					if _elapsed >= deadline:
						_stream_deadline_misses[plate_key] = _elapsed
					return
				_accept_stream_texture(spec, fixture_status.get("texture", null))
			else:
				_accept_stream_texture(spec, fixture_result)
			_release_completed_plates()
			continue
		var result := ProjectResourceLoader.prewarm_texture_threaded_step(
			path,
			"한미량 프롤로그 스트리밍 이미지가 없습니다: %s",
			"한미량 프롤로그 스트리밍 이미지를 불러오지 못했습니다: %s",
			LIVE_STREAM_MAX_MSEC,
			LIVE_STREAM_MAX_POLLS,
			LIVE_STREAM_ALLOW_SYNC_FALLBACK,
			true,
			false
		)
		if not bool(result.get("done", true)):
			if _elapsed >= deadline:
				_stream_deadline_misses[plate_key] = _elapsed
			return
		_accept_stream_texture(spec, result.get("texture", null))
		_release_completed_plates()


func _accept_stream_texture(spec: Dictionary, texture_value: Variant) -> void:
	var plate_key := str(spec.get("key", ""))
	var deadline := float(spec.get("deadline", 0.0))
	if texture_value is Texture2D:
		_stream_textures[plate_key] = texture_value
		if _host != null and is_instance_valid(_host):
			_host.set_plate_texture(plate_key, texture_value)
		if _elapsed > deadline + 0.0001:
			_stream_deadline_misses[plate_key] = _elapsed
	else:
		_stream_deadline_misses[plate_key] = _elapsed
	_stream_index += 1
	_record_resident_count()


func _release_completed_plates() -> void:
	# A missing intermediate plate keeps the latest available predecessor alive
	# until a later successful plate has fully replaced that fallback. This keeps
	# failure paths visible without letting a missing B/C/D plate inflate the
	# resident set beyond the normal four-plate ceiling.
	for plate_index in range(PLATE_TIMELINE_SPECS.size() - 1):
		var plate_spec: Dictionary = PLATE_TIMELINE_SPECS[plate_index]
		var plate_key := str(plate_spec.get("key", ""))
		if not _has_resident_plate(plate_key):
			continue
		for successor_index in range(plate_index + 1, PLATE_TIMELINE_SPECS.size()):
			var successor_spec: Dictionary = PLATE_TIMELINE_SPECS[successor_index]
			var successor_key := str(successor_spec.get("key", ""))
			if not _has_resident_plate(successor_key):
				continue
			if _elapsed >= float(successor_spec.get("replacement_end", INF)):
				_release_plate(plate_key, str(plate_spec.get("path", "")), true)
			break
	_update_family_release_flags()


func _release_plate(plate_key: String, path: String, record_timeline_release: bool = false) -> void:
	var was_resident := _has_resident_plate(plate_key)
	_startup_textures.erase(plate_key)
	_stream_textures.erase(plate_key)
	if _host != null and is_instance_valid(_host):
		_host.release_plate_texture(plate_key)
	ProjectResourceLoader.discard_threaded_texture_result(path)
	if record_timeline_release and was_resident:
		_released_plate_keys[plate_key] = _elapsed
	_record_resident_count()


func _has_resident_plate(plate_key: String) -> bool:
	return (
		_startup_textures.get(plate_key, null) is Texture2D
		or _stream_textures.get(plate_key, null) is Texture2D
	)


func _get_resident_count() -> int:
	return _startup_textures.size() + _stream_textures.size()


func _record_resident_count() -> void:
	_resident_peak = maxi(_resident_peak, _get_resident_count())


func _update_family_release_flags() -> void:
	_a_family_released = (
		not _has_resident_plate(PrologueOverlayHost.PLATE_A1)
		and not _has_resident_plate(PrologueOverlayHost.PLATE_A2)
		and not _has_resident_plate(PrologueOverlayHost.PLATE_A3)
	)
	_b_family_released = (
		not _has_resident_plate(PrologueOverlayHost.PLATE_B1)
		and not _has_resident_plate(PrologueOverlayHost.PLATE_B2)
	)


func _finish(reason: String) -> void:
	_restore_story_audio()
	_completion_reason = reason
	_progress_store.mark_seen(CINEMATIC_ID)
	_phase = PHASE_COMPLETE
	_stop_and_hide_host()
	_discard_all_plate_references()


func _sync_host(owner: Object, fade_alpha: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_host.sync_layout(_get_view_size(owner))
	var segment := PrologueText.get_segment_at(_segments, _elapsed)
	if segment.is_empty():
		segment = PrologueText.get_segment_at(_elapsed_segments, _elapsed)
	_host.sync_timeline(_elapsed, fade_alpha, segment, _elapsed >= _skip_lock_seconds)


func _sync_story_audio(previous_elapsed: float) -> void:
	if not _rays_cue_played and previous_elapsed < RAYS_CUE_SECONDS and _elapsed >= RAYS_CUE_SECONDS:
		_rays_cue_played = true
		_play_audio_method("play_han_miryang_prologue_rays")
	if not _spirit_bell_cue_played and previous_elapsed < SPIRIT_BELL_CUE_SECONDS and _elapsed >= SPIRIT_BELL_CUE_SECONDS:
		_spirit_bell_cue_played = true
		_play_audio_method("play_han_miryang_prologue_spirit_bell")
	var audio := _get_audio()
	if audio == null or not audio.has_method("set_story_cinematic_bgm_gain_db"):
		return
	var gain_db := 0.0
	if _elapsed >= BGM_DUCK_START and _elapsed < BGM_DUCK_END:
		gain_db = lerpf(0.0, BGM_DUCK_GAIN_DB, _smoothstep(BGM_DUCK_START, BGM_DUCK_END, _elapsed))
	elif _elapsed >= BGM_DUCK_END and _elapsed < BGM_SILENCE_FADE_START:
		gain_db = BGM_DUCK_GAIN_DB
	elif _elapsed >= BGM_SILENCE_FADE_START and _elapsed < BGM_SILENCE_START:
		gain_db = lerpf(BGM_DUCK_GAIN_DB, BGM_SILENT_GAIN_DB, _smoothstep(BGM_SILENCE_FADE_START, BGM_SILENCE_START, _elapsed))
	elif _elapsed >= BGM_SILENCE_START and _elapsed < BGM_RESTORE_START:
		gain_db = BGM_SILENT_GAIN_DB
	elif _elapsed >= BGM_RESTORE_START and _elapsed < BGM_RESTORE_END:
		gain_db = lerpf(BGM_SILENT_GAIN_DB, 0.0, _smoothstep(BGM_RESTORE_START, BGM_RESTORE_END, _elapsed))
	elif _elapsed >= BGM_RESTORE_END:
		if audio.has_method("clear_story_cinematic_bgm_gain"):
			audio.clear_story_cinematic_bgm_gain()
		return
	audio.set_story_cinematic_bgm_gain_db(gain_db)


func _play_opening_drum() -> void:
	if _opening_drum_played:
		return
	_opening_drum_played = true
	_play_audio_method("play_han_miryang_prologue_opening_drum")


func _play_audio_method(method_name: String) -> void:
	var audio := _get_audio()
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _restore_story_audio() -> void:
	var audio := _get_audio()
	if audio == null:
		return
	if audio.has_method("clear_story_cinematic_bgm_gain"):
		audio.clear_story_cinematic_bgm_gain()
	if audio.has_method("stop_han_miryang_prologue_cues"):
		audio.stop_han_miryang_prologue_cues()


func _discard_all_plate_references() -> void:
	for spec_value in STARTUP_TEXTURE_SPECS:
		var spec: Dictionary = spec_value
		_release_plate(str(spec.get("key", "")), str(spec.get("path", "")))
	for spec_value in STREAM_TEXTURE_SPECS:
		var spec: Dictionary = spec_value
		_release_plate(str(spec.get("key", "")), str(spec.get("path", "")))
	_startup_textures.clear()
	_stream_textures.clear()
	_stream_texture_factory_for_test = Callable()
	_update_family_release_flags()


func _get_audio() -> Object:
	if _registry == null or not _registry.has_method("get_instance"):
		return null
	var value: Variant = _registry.get_instance("game_audio")
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _ensure_host(owner: Object) -> Control:
	if _host != null and is_instance_valid(_host):
		return _host
	_host = null
	if not (owner is Node):
		return null
	var host: Control = PrologueOverlayHost.new()
	(owner as Node).add_child(host)
	host.set_inactive()
	_host = host
	return _host


func _stop_and_hide_host() -> void:
	if _host != null and is_instance_valid(_host):
		_host.set_inactive()


func _peek_entry_request(owner: Object) -> bool:
	if _entry_request_override_for_test != null:
		return bool(_entry_request_override_for_test)
	var state := _get_selection_state(owner)
	return (
		state != null
		and state.has_method("peek_character_prologue_entry_request")
		and bool(state.peek_character_prologue_entry_request())
	)


func _consume_entry_request(owner: Object) -> bool:
	if _entry_request_override_for_test != null:
		var requested := bool(_entry_request_override_for_test)
		_entry_request_override_for_test = false
		return requested
	var state := _get_selection_state(owner)
	if state != null and state.has_method("consume_character_prologue_entry_request"):
		return bool(state.consume_character_prologue_entry_request())
	return false


func _get_selection_state(owner: Object) -> Object:
	if owner == null or not owner.has_method("get_node_or_null"):
		return null
	return owner.get_node_or_null("/root/GameSelectionState")


func _get_current_stage(owner: Object) -> int:
	if owner != null:
		var value: Variant = owner.get("current_stage")
		if value != null:
			return int(value)
	return STAGE_ID


func _get_runtime_character_id(owner: Object) -> String:
	if owner != null:
		for property_name in ["selected_runtime_character_id", "selected_character_type"]:
			var value: Variant = owner.get(property_name)
			if value != null and str(value).strip_edges() != "":
				return str(value)
	return ""


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport"):
		var viewport: Viewport = owner.get_viewport()
		if viewport != null:
			return viewport.get_visible_rect().size
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2(1920.0, 1080.0)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if edge1 <= edge0:
		return 1.0 if value >= edge1 else 0.0
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _is_skip_pressed(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_SPACE
			or key_event.physical_keycode == KEY_SPACE
			or key_event.keycode == KEY_ENTER
			or key_event.keycode == KEY_ESCAPE
		)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and (joy_event.button_index == JOY_BUTTON_A or joy_event.button_index == JOY_BUTTON_B)
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false
