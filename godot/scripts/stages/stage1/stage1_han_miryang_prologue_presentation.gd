extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StoryCinematicProgressStore := preload("res://scripts/core/story_cinematic_progress_store.gd")
const PrologueText := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_text.gd")
const PrologueOverlayHost := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_overlay_host.gd")

const CINEMATIC_ID := "han_miryang_araul_first_beat_v1"
const STAGE_ID := 1
const RUNTIME_CHARACTER_ID := "smasher"
const DURATION_SECONDS := 38.0
const SKIP_FADE_SECONDS := 0.45
const FIRST_VIEW_SKIP_LOCK_SECONDS := 1.2
const NATURAL_FADE_START_SECONDS := 37.5
const MISSING_BEAT_CUE_SECONDS := 16.05
const BGM_GAP_FADE_OUT_START := 15.55
const BGM_GAP_SILENCE_START := 15.95
const BGM_GAP_RESTORE_START := 16.55
const BGM_GAP_RESTORE_END := 17.10
const BGM_GAP_MIN_GAIN_DB := -80.0
const FIRST_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_coronation_keyart_bishoujo_v2.png"
const STRIKE_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_ball_strike_no_tablet_keyart_bishoujo_v2.png"
const SECOND_TEXTURE_PATH := "res://assets/ui/story/han_miryang_prologue/araul_missing_beat_keyart_bishoujo_v2.png"

const PHASE_IDLE := "idle"
const PHASE_LOADING := "loading"
const PHASE_ACTIVE := "active"
const PHASE_SKIP_FADE := "skip_fade"
const PHASE_COMPLETE := "complete"

var _phase := PHASE_IDLE
var _elapsed := 0.0
var _skip_elapsed := 0.0
var _completion_reason := ""
var _prewarm_index := 0
var _first_texture: Texture2D = null
var _strike_texture: Texture2D = null
var _second_texture: Texture2D = null
var _host: Control = null
var _segments: Array = []
var _copy: Dictionary = {}
var _progress_store: Object = StoryCinematicProgressStore.new()
var _entry_request_override_for_test: Variant = null
var _skip_lock_seconds := FIRST_VIEW_SKIP_LOCK_SECONDS
var _missing_beat_cue_played := false
var _registry: Object = null


static func get_texture_paths() -> Array[String]:
	return [FIRST_TEXTURE_PATH, STRIKE_TEXTURE_PATH, SECOND_TEXTURE_PATH]


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
	if _prewarm_index >= 3:
		return true
	var paths := get_texture_paths()
	var path := paths[_prewarm_index]
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
	if _prewarm_index == 0:
		_first_texture = texture_value as Texture2D if texture_value is Texture2D else null
	elif _prewarm_index == 1:
		_strike_texture = texture_value as Texture2D if texture_value is Texture2D else null
	else:
		_second_texture = texture_value as Texture2D if texture_value is Texture2D else null
	_prewarm_index += 1
	return _prewarm_index >= 3


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
		_phase = PHASE_COMPLETE
		_completion_reason = "host_unavailable"
		return false
	return _start(owner)


func update(delta: float, owner: Object, _registry: Object) -> void:
	if _phase == PHASE_LOADING:
		if prewarm_assets_step() and prewarm_runtime_nodes_step(owner):
			_start(owner)
		return
	if _phase == PHASE_ACTIVE:
		var previous_elapsed := _elapsed
		_elapsed += maxf(0.0, delta)
		_sync_missing_beat_audio(previous_elapsed)
		var natural_fade_alpha := _smoothstep(
			NATURAL_FADE_START_SECONDS,
			DURATION_SECONDS,
			_elapsed
		)
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


func handle_input(event: InputEvent, _owner: Object, _registry: Object) -> bool:
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
		"first_path": FIRST_TEXTURE_PATH,
		"strike_path": STRIKE_TEXTURE_PATH,
		"second_path": SECOND_TEXTURE_PATH,
		"first_ready": _first_texture != null,
		"strike_ready": _strike_texture != null,
		"second_ready": _second_texture != null,
		"prewarm_index": _prewarm_index,
		"host_ready": _host != null and is_instance_valid(_host),
	}


func set_progress_path_for_test(path: String) -> void:
	_progress_store.set_save_path(path)


func set_entry_request_override_for_test(value: Variant) -> void:
	_entry_request_override_for_test = value


func tear_down() -> void:
	_restore_story_audio()
	if _host != null and is_instance_valid(_host):
		_host.tear_down(true)
	_host = null
	_registry = null
	_phase = PHASE_COMPLETE
	_completion_reason = "teardown"


func _start(owner: Object) -> bool:
	if _first_texture == null or _strike_texture == null or _second_texture == null:
		_phase = PHASE_COMPLETE
		_completion_reason = "asset_unavailable"
		return false
	var host := _ensure_host(owner)
	if host == null:
		_phase = PHASE_COMPLETE
		_completion_reason = "host_unavailable"
		return false
	var locale := LanguageSettings.get_language()
	_segments = PrologueText.get_segments(locale)
	_copy = PrologueText.get_copy(locale)
	_skip_lock_seconds = 0.0 if _progress_store.has_seen(CINEMATIC_ID) else FIRST_VIEW_SKIP_LOCK_SECONDS
	_elapsed = 0.0
	_skip_elapsed = 0.0
	_missing_beat_cue_played = false
	_completion_reason = ""
	_phase = PHASE_ACTIVE
	host.sync_layout(_get_view_size(owner))
	if not bool(host.begin(_first_texture, _strike_texture, _second_texture, _copy)):
		_phase = PHASE_COMPLETE
		_completion_reason = "host_start_failed"
		return false
	_sync_host(owner, 0.0)
	return true


func _finish(reason: String) -> void:
	_restore_story_audio()
	_completion_reason = reason
	_progress_store.mark_seen(CINEMATIC_ID)
	_phase = PHASE_COMPLETE
	_stop_and_hide_host()


func _sync_host(owner: Object, fade_alpha: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_host.sync_layout(_get_view_size(owner))
	_host.sync_timeline(
		_elapsed,
		fade_alpha,
		PrologueText.get_segment_at(_segments, _elapsed),
		_elapsed >= _skip_lock_seconds
	)


func _sync_missing_beat_audio(previous_elapsed: float) -> void:
	var audio := _get_audio()
	if (
		not _missing_beat_cue_played
		and previous_elapsed < MISSING_BEAT_CUE_SECONDS
		and _elapsed >= MISSING_BEAT_CUE_SECONDS
	):
		_missing_beat_cue_played = true
		if audio != null and audio.has_method("play_han_miryang_prologue_missing_beat"):
			audio.play_han_miryang_prologue_missing_beat()
	if audio == null:
		return
	if _elapsed < BGM_GAP_FADE_OUT_START:
		return
	if _elapsed >= BGM_GAP_RESTORE_END:
		if audio.has_method("clear_story_cinematic_bgm_gain"):
			audio.clear_story_cinematic_bgm_gain()
		return
	var gain_db := BGM_GAP_MIN_GAIN_DB
	if _elapsed < BGM_GAP_SILENCE_START:
		gain_db = lerpf(
			0.0,
			BGM_GAP_MIN_GAIN_DB,
			_smoothstep(BGM_GAP_FADE_OUT_START, BGM_GAP_SILENCE_START, _elapsed)
		)
	elif _elapsed >= BGM_GAP_RESTORE_START:
		gain_db = lerpf(
			BGM_GAP_MIN_GAIN_DB,
			0.0,
			_smoothstep(BGM_GAP_RESTORE_START, BGM_GAP_RESTORE_END, _elapsed)
		)
	if audio.has_method("set_story_cinematic_bgm_gain_db"):
		audio.set_story_cinematic_bgm_gain_db(gain_db)


func _restore_story_audio() -> void:
	var audio := _get_audio()
	if audio == null:
		return
	if audio.has_method("clear_story_cinematic_bgm_gain"):
		audio.clear_story_cinematic_bgm_gain()
	if audio.has_method("stop_han_miryang_prologue_missing_beat"):
		audio.stop_han_miryang_prologue_missing_beat()


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
