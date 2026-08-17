extends Node

signal current_scene_released

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const HEADLESS_LOAD_QUIT_ARG_PREFIX := "--ringpia-headless-load-quit-after="
const HEADLESS_LOAD_QUIT_MARKER := "[ApplicationQuitCoordinator] graceful headless shutdown complete"
const AUDIO_DRAIN_MSEC := 300

var _quit_pending: bool = false
var _quit_exit_code: int = 0
var _headless_quit_after_frames: int = -1
var _headless_frame_count: int = 0
var _current_scene_released: bool = false
var _audio_drain_started_msec: int = 0
var _post_drain_frames_remaining: int = 0
var _scene_release_signal_emitted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	if tree != null:
		# Window-close notifications must pass through request_quit() so the
		# current scene and audio playback are retired before ObjectDB cleanup.
		tree.auto_accept_quit = false
	_headless_quit_after_frames = _read_headless_quit_after_frames()
	set_process(_headless_quit_after_frames > 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


func _process(_delta: float) -> void:
	if _quit_pending:
		_advance_pending_quit()
		return
	if _headless_quit_after_frames <= 0:
		return
	_headless_frame_count += 1
	if _headless_frame_count >= _headless_quit_after_frames:
		request_quit()


func request_quit(exit_code: int = 0) -> void:
	if _quit_pending:
		return
	_quit_pending = true
	_quit_exit_code = exit_code
	set_process(true)
	var tree := get_tree()
	if tree == null:
		return
	_stop_audio_players(tree.root)
	call_deferred("_begin_shutdown_drain")


func is_quit_pending() -> bool:
	return _quit_pending


func _begin_shutdown_drain() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_release_current_scene_if_present(tree)
	ProjectResourceLoader.clear_caches()
	_restart_drain_window()
	_emit_scene_released_once()


func _release_current_scene_if_present(tree: SceneTree) -> bool:
	var outgoing_scene := tree.current_scene
	if outgoing_scene == null:
		return false
	tree.current_scene = null
	if is_instance_valid(outgoing_scene):
		outgoing_scene.free()
	return true


func _restart_drain_window() -> void:
	_current_scene_released = true
	_audio_drain_started_msec = Time.get_ticks_msec()
	_post_drain_frames_remaining = 2


func _emit_scene_released_once() -> void:
	if _scene_release_signal_emitted:
		return
	_scene_release_signal_emitted = true
	current_scene_released.emit()


func _advance_pending_quit() -> void:
	if not _current_scene_released:
		return
	var tree := get_tree()
	if tree == null:
		return
	# change_scene_to_file() temporarily clears current_scene and installs the
	# incoming scene later. A quit request can land inside that gap. Drain any
	# late scene/audio that appears and restart the quiet window before exit.
	_stop_audio_players(tree.root)
	if _release_current_scene_if_present(tree):
		ProjectResourceLoader.clear_caches()
		_restart_drain_window()
		return
	if Time.get_ticks_msec() - _audio_drain_started_msec < AUDIO_DRAIN_MSEC:
		return
	if _post_drain_frames_remaining > 0:
		_post_drain_frames_remaining -= 1
		return
	_finalize_quit()


func _finalize_quit() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_stop_audio_players(tree.root)
	if _release_current_scene_if_present(tree):
		ProjectResourceLoader.clear_caches()
		_restart_drain_window()
		return
	set_process(false)
	if _headless_quit_after_frames > 0:
		print(HEADLESS_LOAD_QUIT_MARKER)
	tree.quit(_quit_exit_code)


func _stop_audio_players(tree_root: Node) -> void:
	if tree_root == null or not is_instance_valid(tree_root):
		return
	var pending: Array[Node] = [tree_root]
	_stop_audio_players_from_pending(pending)


func _stop_audio_players_from_pending(pending: Array[Node]) -> void:
	while not pending.is_empty():
		var current_value: Variant = pending.pop_back()
		# Shutdown keeps draining for several frames while queued nodes disappear.
		# A node collected on the previous walk can therefore become null before
		# this pass reaches it; never dereference that retired queue entry.
		if current_value == null or not is_instance_valid(current_value):
			continue
		var current := current_value as Node
		for child in current.get_children():
			if child != null and is_instance_valid(child):
				pending.append(child)
		if current is AudioStreamPlayer:
			var player := current as AudioStreamPlayer
			player.stop()
			player.stream = null
		elif current is AudioStreamPlayer2D:
			var player_2d := current as AudioStreamPlayer2D
			player_2d.stop()
			player_2d.stream = null
		elif current is AudioStreamPlayer3D:
			var player_3d := current as AudioStreamPlayer3D
			player_3d.stop()
			player_3d.stream = null


func _read_headless_quit_after_frames() -> int:
	for argument_value in OS.get_cmdline_user_args():
		var argument := str(argument_value)
		if not argument.begins_with(HEADLESS_LOAD_QUIT_ARG_PREFIX):
			continue
		var frame_text := argument.trim_prefix(HEADLESS_LOAD_QUIT_ARG_PREFIX)
		if frame_text.is_valid_int():
			return maxi(frame_text.to_int(), 1)
	return -1
