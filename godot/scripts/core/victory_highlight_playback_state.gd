extends RefCounted

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const CONTENT_TOP := 118.0
const CONTENT_BOTTOM := 678.0
const SKIP_GUARD_SEC := 0.15
const SKIP_HOLD_SEC := 0.60
const CLIP_FADE_SEC := 0.12
const MIN_TOTAL_PRESENTATION_SEC := 2.80
const MAX_TOTAL_PRESENTATION_SEC := 3.20
const TIMELINE_BOUNDARY_EPSILON_SEC := 0.000001
const OWNER_ACTIVE_KEY := "victory_highlight_active"

class ReplayDrawBridge:
	extends Control

	var renderer: Object = null
	var playback: Object = null
	var draw_layer := "overlay"

	func _draw() -> void:
		if renderer == null:
			return
		match draw_layer:
			"background":
				if renderer.has_method("draw_background"):
					renderer.draw_background(self, playback)
			"state_content":
				if renderer.has_method("draw_state_content"):
					renderer.draw_state_content(self, playback)
				elif renderer.has_method("draw_content"):
					renderer.draw_content(self, playback)
			"frame_content":
				if renderer.has_method("draw_frame_content"):
					renderer.draw_frame_content(self, playback)
			"content":
				if renderer.has_method("draw_content"):
					renderer.draw_content(self, playback)
			_:
				if renderer.has_method("draw_overlay"):
					renderer.draw_overlay(self, playback)


var _active := false
var _clips: Array[Dictionary] = []
var _clip_index := 0
var _clip_elapsed_sec := 0.0
var _clip_transition_elapsed_sec := 0.0
var _active_elapsed_sec := 0.0
var _timeline_speed := 1.0
var _goal_cue_played := false
var _previous_clip: Dictionary = {}
var _previous_clip_index := -1
var _previous_clip_time_sec := 0.0
var _skip_hold_token := ""
var _skip_hold_elapsed_sec := 0.0
var _finish_callback := Callable()
var _owner: Object = null
var _registry: Object = null
var _renderer: Object = null
var _renderer_key := ""
var _host: Node2D = null
var _playfield_clip: Control = null
var _background_bridge: ReplayDrawBridge = null
var _content_clip: Control = null
var _content_draw_bridge: ReplayDrawBridge = null
var _frame_content_draw_bridge: ReplayDrawBridge = null
var _draw_bridge: ReplayDrawBridge = null


func start(
	owner: Object,
	registry: Object,
	clips: Array[Dictionary],
	finish_callback: Callable
) -> bool:
	if _active or clips.is_empty() or not (owner is Node):
		return false
	var renderer_key := (
		"victory_highlight_frame_renderer"
		if _clips_include_frame_payload(clips)
		else "victory_highlight_renderer"
	)
	var renderer: Object = _get_instance(registry, renderer_key)
	if renderer_key == "victory_highlight_frame_renderer" and renderer != null:
		if renderer.has_method("configure_base_renderer"):
			renderer.configure_base_renderer(_get_instance(registry, "victory_highlight_renderer"))
		if renderer.has_method("configure_for_clips") and not bool(renderer.configure_for_clips(clips)):
			renderer = null
	if renderer == null and renderer_key == "victory_highlight_frame_renderer":
		renderer_key = "victory_highlight_renderer"
		renderer = _get_instance(registry, renderer_key)
	if renderer == null or not renderer.has_method("draw"):
		return false
	_owner = owner
	_registry = registry
	_renderer = renderer
	_renderer_key = renderer_key
	if OS.is_debug_build():
		print("victory_highlight_playback_renderer: %s" % _renderer_key)
	_clips = clips.duplicate()
	_clip_index = 0
	_clip_elapsed_sec = 0.0
	_clip_transition_elapsed_sec = 0.0
	_active_elapsed_sec = 0.0
	_goal_cue_played = false
	_previous_clip = {}
	_previous_clip_index = -1
	_previous_clip_time_sec = 0.0
	_reset_skip_hold()
	_finish_callback = finish_callback
	_timeline_speed = _calculate_timeline_speed(clips)
	_build_host(owner as Node)
	_set_owner_active(true)
	_active = true
	_prepare_renderer_frame()
	_stop_gameplay_audio()
	_play_transition_cue()
	_queue_bridge_redraw()
	return true


func update(delta: float) -> void:
	if not _active:
		return
	var wall_delta: float = maxf(0.0, delta)
	if not _skip_hold_token.is_empty():
		_skip_hold_elapsed_sec = minf(SKIP_HOLD_SEC, _skip_hold_elapsed_sec + wall_delta)
		if _skip_hold_elapsed_sec >= SKIP_HOLD_SEC:
			_complete(true)
			return
	var scaled_delta: float = maxf(0.0, delta) * _timeline_speed
	_active_elapsed_sec += wall_delta
	_clip_transition_elapsed_sec += wall_delta
	_clip_elapsed_sec += scaled_delta
	if _clip_transition_elapsed_sec >= CLIP_FADE_SEC:
		_previous_clip = {}
		_previous_clip_index = -1
		_previous_clip_time_sec = 0.0
	_emit_goal_cue_if_needed()
	while _active:
		var clip: Dictionary = get_current_clip()
		var duration_sec: float = maxf(0.01, float(clip.get("duration_sec", 0.01)))
		if _clip_elapsed_sec + TIMELINE_BOUNDARY_EPSILON_SEC < duration_sec:
			break
		_clip_elapsed_sec = maxf(0.0, _clip_elapsed_sec - duration_sec)
		if _clip_index + 1 >= _clips.size():
			_complete(true)
			return
		_previous_clip = clip
		_previous_clip_index = _clip_index
		_previous_clip_time_sec = duration_sec
		_clip_index += 1
		_clip_transition_elapsed_sec = 0.0
		_goal_cue_played = false
		_play_transition_cue()
		_emit_goal_cue_if_needed()
	_prepare_renderer_frame()
	_queue_bridge_redraw()


func handle_input(event: InputEvent) -> bool:
	if not _active or event == null:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_F9 or key_event.physical_keycode == KEY_F9:
			return false
		if key_event.echo:
			return not _skip_hold_token.is_empty()
		var key_token := _key_hold_token(key_event)
		if key_event.pressed:
			return _begin_skip_hold(key_token)
		return _end_skip_hold(key_token)
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		var mouse_token := "mouse:%d" % int(mouse_event.button_index)
		if mouse_event.pressed:
			return _begin_skip_hold(mouse_token)
		return _end_skip_hold(mouse_token)
	return false


func sync_host_layout(layout: Dictionary) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var offset_value: Variant = layout.get("game_offset", Vector2.ZERO)
	var game_offset: Vector2 = offset_value if offset_value is Vector2 else Vector2.ZERO
	var render_scale: float = maxf(0.001, float(layout.get("render_scale", 1.0)))
	_host.position = game_offset
	_host.scale = Vector2.ONE * render_scale


func reset(_owner_override: Object = null) -> void:
	_complete(false)


func is_active() -> bool:
	return _active


func get_current_clip() -> Dictionary:
	if not _active or _clip_index < 0 or _clip_index >= _clips.size():
		return {}
	return _clips[_clip_index]


func get_clip_local_time() -> float:
	return _clip_elapsed_sec


func get_active_elapsed_sec() -> float:
	return _active_elapsed_sec


func get_clip_transition_elapsed_sec() -> float:
	return _clip_transition_elapsed_sec


func get_current_clip_index() -> int:
	return _clip_index


func get_clip_count() -> int:
	return _clips.size()


func get_content_alpha() -> float:
	return clampf(_clip_transition_elapsed_sec / CLIP_FADE_SEC, 0.0, 1.0)


func get_skip_hold_progress() -> float:
	if _skip_hold_token.is_empty():
		return 0.0
	return clampf(_skip_hold_elapsed_sec / SKIP_HOLD_SEC, 0.0, 1.0)


func is_skip_hold_active() -> bool:
	return not _skip_hold_token.is_empty()


func get_previous_clip() -> Dictionary:
	return _previous_clip


func get_previous_clip_index() -> int:
	return _previous_clip_index


func get_previous_clip_time() -> float:
	return _previous_clip_time_sec


func get_host_debug_snapshot() -> Dictionary:
	return {
		"active": _active,
		"host_exists": _host != null and is_instance_valid(_host),
		"host_process_enabled": _host != null and is_instance_valid(_host) and _host.is_processing(),
		"clip_exists": _playfield_clip != null and is_instance_valid(_playfield_clip),
		"clip_contents": _playfield_clip != null and is_instance_valid(_playfield_clip) and _playfield_clip.clip_contents,
		"clip_position": _playfield_clip.position if _playfield_clip != null and is_instance_valid(_playfield_clip) else Vector2.ZERO,
		"clip_size": _playfield_clip.size if _playfield_clip != null and is_instance_valid(_playfield_clip) else Vector2.ZERO,
		"content_clip_exists": _content_clip != null and is_instance_valid(_content_clip),
		"content_clip_contents": _content_clip != null and is_instance_valid(_content_clip) and _content_clip.clip_contents,
		"content_clip_position": _content_clip.position if _content_clip != null and is_instance_valid(_content_clip) else Vector2.ZERO,
		"content_clip_size": _content_clip.size if _content_clip != null and is_instance_valid(_content_clip) else Vector2.ZERO,
		"frame_content_exists": _frame_content_draw_bridge != null and is_instance_valid(_frame_content_draw_bridge),
		"frame_content_position": _frame_content_draw_bridge.position if _frame_content_draw_bridge != null and is_instance_valid(_frame_content_draw_bridge) else Vector2.ZERO,
		"frame_content_size": _frame_content_draw_bridge.size if _frame_content_draw_bridge != null and is_instance_valid(_frame_content_draw_bridge) else Vector2.ZERO,
		"current_content_mode": (
			"frame_full_canvas"
			if _renderer_key == "victory_highlight_frame_renderer"
			and _clip_has_frame_payload(get_current_clip())
			else "state_band"
		),
		"clip_index": _clip_index,
		"clip_count": _clips.size(),
		"timeline_speed": _timeline_speed,
		"renderer_key": _renderer_key,
		"skip_hold_active": is_skip_hold_active(),
		"skip_hold_progress": get_skip_hold_progress(),
		"host_children": _debug_child_names(_host),
		"clip_children": _debug_child_names(_playfield_clip),
		"content_clip_children": _debug_child_names(_content_clip),
		"background_parent": _debug_parent_name(_background_bridge),
		"state_content_parent": _debug_parent_name(_content_draw_bridge),
		"frame_content_parent": _debug_parent_name(_frame_content_draw_bridge),
		"overlay_parent": _debug_parent_name(_draw_bridge),
	}


func _debug_child_names(parent: Node) -> Array[String]:
	var names: Array[String] = []
	if parent == null or not is_instance_valid(parent):
		return names
	for child in parent.get_children():
		names.append(str(child.name))
	return names


func _debug_parent_name(child: Node) -> String:
	if child == null or not is_instance_valid(child):
		return ""
	var parent := child.get_parent()
	return str(parent.name) if parent != null else ""


func _build_host(owner_node: Node) -> void:
	_tear_down_host()
	_host = Node2D.new()
	_host.name = "VictoryHighlightReplayFxHost"
	_host.z_index = 950
	_host.set_process(false)
	owner_node.add_child(_host)

	_playfield_clip = Control.new()
	_playfield_clip.name = "VictoryHighlightPlayfieldClip"
	_playfield_clip.position = Vector2.ZERO
	_playfield_clip.size = GAME_SIZE
	_playfield_clip.clip_contents = true
	_playfield_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_playfield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(_playfield_clip)

	_background_bridge = ReplayDrawBridge.new()
	_background_bridge.name = "VictoryHighlightBackgroundBridge"
	_background_bridge.renderer = _renderer
	_background_bridge.playback = self
	_background_bridge.draw_layer = "background"
	_background_bridge.position = Vector2.ZERO
	_background_bridge.size = GAME_SIZE
	_background_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_clip.add_child(_background_bridge)

	_content_clip = Control.new()
	_content_clip.name = "VictoryHighlightContentClip"
	_content_clip.position = Vector2(0.0, CONTENT_TOP)
	_content_clip.size = Vector2(GAME_SIZE.x, CONTENT_BOTTOM - CONTENT_TOP)
	_content_clip.clip_contents = true
	_content_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_content_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_clip.add_child(_content_clip)

	_content_draw_bridge = ReplayDrawBridge.new()
	_content_draw_bridge.name = "VictoryHighlightContentDrawBridge"
	_content_draw_bridge.renderer = _renderer
	_content_draw_bridge.playback = self
	_content_draw_bridge.draw_layer = "state_content"
	_content_draw_bridge.position = Vector2(0.0, -CONTENT_TOP)
	_content_draw_bridge.size = GAME_SIZE
	_content_draw_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_clip.add_child(_content_draw_bridge)

	_frame_content_draw_bridge = ReplayDrawBridge.new()
	_frame_content_draw_bridge.name = "VictoryHighlightFrameContentDrawBridge"
	_frame_content_draw_bridge.renderer = _renderer
	_frame_content_draw_bridge.playback = self
	_frame_content_draw_bridge.draw_layer = "frame_content"
	_frame_content_draw_bridge.position = Vector2.ZERO
	_frame_content_draw_bridge.size = GAME_SIZE
	_frame_content_draw_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _renderer.has_method("get_content_material"):
		_frame_content_draw_bridge.material = _renderer.get_content_material()
	_playfield_clip.add_child(_frame_content_draw_bridge)

	_draw_bridge = ReplayDrawBridge.new()
	_draw_bridge.name = "VictoryHighlightDrawBridge"
	_draw_bridge.renderer = _renderer
	_draw_bridge.playback = self
	_draw_bridge.draw_layer = "overlay"
	_draw_bridge.position = Vector2.ZERO
	_draw_bridge.size = GAME_SIZE
	_draw_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_clip.add_child(_draw_bridge)


func _complete(call_finish: bool) -> void:
	var was_active := _active
	var callback: Callable = _finish_callback
	_active = false
	_set_owner_active(false)
	_finish_callback = Callable()
	_tear_down_host()
	_release_recorded_clips()
	_clips.clear()
	_clip_index = 0
	_clip_elapsed_sec = 0.0
	_clip_transition_elapsed_sec = 0.0
	_active_elapsed_sec = 0.0
	_goal_cue_played = false
	_previous_clip = {}
	_previous_clip_index = -1
	_previous_clip_time_sec = 0.0
	_reset_skip_hold()
	_renderer = null
	_renderer_key = ""
	_registry = null
	_owner = null
	if was_active and call_finish and callback.is_valid():
		callback.call()


func _tear_down_host() -> void:
	if _host != null and is_instance_valid(_host):
		# 씬 전환 프레임에는 부모 트리가 바빠 remove_child()가 거부될 수
		# 있고, 그 상태의 free()는 부모 목록을 손상시킨다(캡처 상태와 동일
		# 계약). 트리에 붙어 있으면 항상 queue_free()로 지연 해제한다.
		if _host.get_parent() != null:
			_host.queue_free()
		else:
			_host.free()
	_host = null
	_playfield_clip = null
	_background_bridge = null
	_content_clip = null
	_content_draw_bridge = null
	_frame_content_draw_bridge = null
	_draw_bridge = null


func _release_recorded_clips() -> void:
	var recorder: Object = _get_instance(_registry, "victory_highlight_recorder")
	if recorder != null and recorder.has_method("release_match_clips"):
		recorder.release_match_clips()


func _calculate_timeline_speed(clips: Array[Dictionary]) -> float:
	if _clips_include_frame_payload(clips):
		return 1.0
	var total_sec := 0.0
	for clip in clips:
		total_sec += maxf(0.0, float(clip.get("duration_sec", 0.0)))
	if total_sec <= 0.001:
		return 1.0
	var target_sec: float = clampf(total_sec, MIN_TOTAL_PRESENTATION_SEC, MAX_TOTAL_PRESENTATION_SEC)
	return total_sec / target_sec


func _clips_include_frame_payload(clips: Array[Dictionary]) -> bool:
	for clip in clips:
		var frames: Array = clip.get("frame_frames", [])
		if not frames.is_empty():
			return true
	return false


func _emit_goal_cue_if_needed() -> void:
	if _goal_cue_played:
		return
	var clip: Dictionary = get_current_clip()
	if clip.is_empty() or _clip_elapsed_sec < float(clip.get("goal_t_sec", INF)):
		return
	_goal_cue_played = true
	var audio: Object = _get_instance(_registry, "game_audio")
	if audio != null and audio.has_method("play_victory_highlight_impact"):
		audio.play_victory_highlight_impact()


func _play_transition_cue() -> void:
	var audio: Object = _get_instance(_registry, "game_audio")
	if audio != null and audio.has_method("play_victory_highlight_transition"):
		audio.play_victory_highlight_transition()


func _stop_gameplay_audio() -> void:
	GameplayLoopAudioCleanup.stop_all(_get_instance(_registry, "game_audio"))


func _set_owner_active(value: bool) -> void:
	if _owner != null:
		_owner.set(OWNER_ACTIVE_KEY, value)


func _begin_skip_hold(token: String) -> bool:
	if token.is_empty() or _active_elapsed_sec < SKIP_GUARD_SEC:
		return false
	if not _skip_hold_token.is_empty():
		return _skip_hold_token == token
	_skip_hold_token = token
	_skip_hold_elapsed_sec = 0.0
	return true


func _end_skip_hold(token: String) -> bool:
	if token.is_empty() or token != _skip_hold_token:
		return false
	_reset_skip_hold()
	return true


func _reset_skip_hold() -> void:
	_skip_hold_token = ""
	_skip_hold_elapsed_sec = 0.0


func _key_hold_token(event: InputEventKey) -> String:
	var code: int = int(event.physical_keycode)
	if code == 0:
		code = int(event.keycode)
	return "key:%d" % code if code != 0 else ""


func _queue_bridge_redraw() -> void:
	if _background_bridge != null and is_instance_valid(_background_bridge):
		_background_bridge.queue_redraw()
	if _content_draw_bridge != null and is_instance_valid(_content_draw_bridge):
		_content_draw_bridge.queue_redraw()
	if _frame_content_draw_bridge != null and is_instance_valid(_frame_content_draw_bridge):
		_frame_content_draw_bridge.queue_redraw()
	if _draw_bridge != null and is_instance_valid(_draw_bridge):
		_draw_bridge.queue_redraw()


func _prepare_renderer_frame() -> void:
	if _renderer == null or not _renderer.has_method("prepare_playback_frame"):
		return
	if bool(_renderer.prepare_playback_frame(self)):
		return
	var fallback := _get_instance(_registry, "victory_highlight_renderer")
	if fallback == null or not fallback.has_method("draw"):
		return
	_renderer = fallback
	_renderer_key = "victory_highlight_renderer"
	for bridge in [_background_bridge, _content_draw_bridge, _frame_content_draw_bridge, _draw_bridge]:
		if bridge != null and is_instance_valid(bridge):
			bridge.renderer = fallback
	if _content_draw_bridge != null and is_instance_valid(_content_draw_bridge):
		_content_draw_bridge.material = null
	if _frame_content_draw_bridge != null and is_instance_valid(_frame_content_draw_bridge):
		_frame_content_draw_bridge.material = null


func _clip_has_frame_payload(clip: Dictionary) -> bool:
	return not clip.is_empty() and not (clip.get("frame_frames", []) as Array).is_empty()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
