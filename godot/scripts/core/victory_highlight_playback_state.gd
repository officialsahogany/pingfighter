extends RefCounted

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const CONTENT_TOP := 118.0
const CONTENT_BOTTOM := 678.0
const SKIP_GUARD_SEC := 0.15
const CLIP_FADE_SEC := 0.12
const MIN_TOTAL_PRESENTATION_SEC := 2.80
const MAX_TOTAL_PRESENTATION_SEC := 3.20
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
var _finish_callback := Callable()
var _owner: Object = null
var _registry: Object = null
var _renderer: Object = null
var _host: Node2D = null
var _playfield_clip: Control = null
var _background_bridge: ReplayDrawBridge = null
var _content_clip: Control = null
var _content_draw_bridge: ReplayDrawBridge = null
var _draw_bridge: ReplayDrawBridge = null


func start(
	owner: Object,
	registry: Object,
	clips: Array[Dictionary],
	finish_callback: Callable
) -> bool:
	if _active or clips.is_empty() or not (owner is Node):
		return false
	var renderer: Object = _get_instance(registry, "victory_highlight_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return false
	_owner = owner
	_registry = registry
	_renderer = renderer
	_clips = clips.duplicate()
	_clip_index = 0
	_clip_elapsed_sec = 0.0
	_clip_transition_elapsed_sec = 0.0
	_active_elapsed_sec = 0.0
	_goal_cue_played = false
	_previous_clip = {}
	_previous_clip_index = -1
	_previous_clip_time_sec = 0.0
	_finish_callback = finish_callback
	_timeline_speed = _calculate_timeline_speed(clips)
	_build_host(owner as Node)
	_set_owner_active(true)
	_active = true
	_stop_gameplay_audio()
	_play_transition_cue()
	_queue_bridge_redraw()
	return true


func update(delta: float) -> void:
	if not _active:
		return
	var scaled_delta: float = maxf(0.0, delta) * _timeline_speed
	_active_elapsed_sec += maxf(0.0, delta)
	_clip_transition_elapsed_sec += maxf(0.0, delta)
	_clip_elapsed_sec += scaled_delta
	if _clip_transition_elapsed_sec >= CLIP_FADE_SEC:
		_previous_clip = {}
		_previous_clip_index = -1
		_previous_clip_time_sec = 0.0
	_emit_goal_cue_if_needed()
	while _active:
		var clip: Dictionary = get_current_clip()
		var duration_sec: float = maxf(0.01, float(clip.get("duration_sec", 0.01)))
		if _clip_elapsed_sec < duration_sec:
			break
		_clip_elapsed_sec -= duration_sec
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
	_queue_bridge_redraw()


func handle_input(event: InputEvent) -> bool:
	if not _active or event == null:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_F9 or key_event.physical_keycode == KEY_F9:
			return false
		if key_event.pressed and not key_event.echo and _active_elapsed_sec >= SKIP_GUARD_SEC:
			_complete(true)
			return true
		return false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and _active_elapsed_sec >= SKIP_GUARD_SEC:
			_complete(true)
			return true
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


func get_current_clip_index() -> int:
	return _clip_index


func get_clip_count() -> int:
	return _clips.size()


func get_content_alpha() -> float:
	return clampf(_clip_transition_elapsed_sec / CLIP_FADE_SEC, 0.0, 1.0)


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
		"clip_index": _clip_index,
		"clip_count": _clips.size(),
		"timeline_speed": _timeline_speed,
	}


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
	_content_draw_bridge.draw_layer = "content"
	_content_draw_bridge.position = Vector2(0.0, -CONTENT_TOP)
	_content_draw_bridge.size = GAME_SIZE
	_content_draw_bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_clip.add_child(_content_draw_bridge)

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
	_renderer = null
	_registry = null
	_owner = null
	if was_active and call_finish and callback.is_valid():
		callback.call()


func _tear_down_host() -> void:
	if _host != null and is_instance_valid(_host):
		var parent: Node = _host.get_parent()
		if parent != null:
			parent.remove_child(_host)
		_host.free()
	_host = null
	_playfield_clip = null
	_background_bridge = null
	_content_clip = null
	_content_draw_bridge = null
	_draw_bridge = null


func _release_recorded_clips() -> void:
	var recorder: Object = _get_instance(_registry, "victory_highlight_recorder")
	if recorder != null and recorder.has_method("release_match_clips"):
		recorder.release_match_clips()


func _calculate_timeline_speed(clips: Array[Dictionary]) -> float:
	var total_sec := 0.0
	for clip in clips:
		total_sec += maxf(0.0, float(clip.get("duration_sec", 0.0)))
	if total_sec <= 0.001:
		return 1.0
	var target_sec: float = clampf(total_sec, MIN_TOTAL_PRESENTATION_SEC, MAX_TOTAL_PRESENTATION_SEC)
	return total_sec / target_sec


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


func _queue_bridge_redraw() -> void:
	if _background_bridge != null and is_instance_valid(_background_bridge):
		_background_bridge.queue_redraw()
	if _content_draw_bridge != null and is_instance_valid(_content_draw_bridge):
		_content_draw_bridge.queue_redraw()
	if _draw_bridge != null and is_instance_valid(_draw_bridge):
		_draw_bridge.queue_redraw()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
