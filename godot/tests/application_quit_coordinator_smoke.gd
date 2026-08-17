extends SceneTree

# expect-zero-object-leaks

const MainMenuAudioController := preload("res://scripts/audio/main_menu_audio_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class ShutdownProbeScene:
	extends Node

	var terminal_owner: RefCounted = RefCounted.new()


	func _exit_tree() -> void:
		terminal_owner = null
		get_tree().root.set_meta("application_quit_probe_scene_exited", true)


var failure_count: int = 0
var probe_scene_weak: WeakRef = null
var root_audio_player: AudioStreamPlayer = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := root.get_node_or_null("ApplicationQuitCoordinator")
	_expect(coordinator != null, "application quit coordinator autoload should exist")
	if coordinator == null:
		quit(1)
		return
	_verify_retired_audio_walk_entry_is_ignored(coordinator)

	var probe_scene := ShutdownProbeScene.new()
	probe_scene.name = "ShutdownProbeScene"
	root.add_child(probe_scene)
	current_scene = probe_scene
	probe_scene_weak = weakref(probe_scene)

	var stream := ProjectResourceLoader.load_audio_stream(
		MainMenuAudioController.MAIN_MENU_BGM_PATH
	)
	_expect(stream != null, "shutdown smoke should load the real menu BGM stream")
	var scene_audio_player := AudioStreamPlayer.new()
	scene_audio_player.name = "SceneAudioPlayer"
	scene_audio_player.stream = stream
	probe_scene.add_child(scene_audio_player)
	root_audio_player = AudioStreamPlayer.new()
	root_audio_player.name = "RootAudioPlayer"
	root_audio_player.stream = stream
	root.add_child(root_audio_player)
	scene_audio_player.play()
	root_audio_player.play()
	await process_frame

	coordinator.current_scene_released.connect(_on_current_scene_released, CONNECT_ONE_SHOT)
	coordinator.request_quit(0)
	_expect(bool(coordinator.is_quit_pending()), "request_quit should become idempotently pending")
	_expect(
		scene_audio_player.stream == null and not scene_audio_player.playing,
		"graceful quit should stop and detach scene-owned audio before scene teardown"
	)
	_expect(
		root_audio_player.stream == null and not root_audio_player.playing,
		"graceful quit should stop and detach root-owned audio before scene teardown"
	)
	coordinator.request_quit(7)


func _verify_retired_audio_walk_entry_is_ignored(coordinator: Object) -> void:
	var retired_node := Node.new()
	var pending: Array[Node] = [retired_node]
	retired_node.free()
	coordinator.call("_stop_audio_players_from_pending", pending)
	_expect(
		pending.is_empty(),
		"shutdown audio walk should skip a node retired after it entered the pending queue"
	)


func _on_current_scene_released() -> void:
	_expect(current_scene == null, "graceful quit should detach the current scene before final quit")
	_expect(
		bool(root.get_meta("application_quit_probe_scene_exited", false)),
		"graceful quit should run the outgoing scene's exit lifecycle"
	)
	_expect(
		probe_scene_weak == null or probe_scene_weak.get_ref() == null,
		"graceful quit should free the outgoing scene while the engine is still alive"
	)
	if root.has_meta("application_quit_probe_scene_exited"):
		root.remove_meta("application_quit_probe_scene_exited")
	if root_audio_player != null and is_instance_valid(root_audio_player):
		root_audio_player.free()
	root_audio_player = null
	probe_scene_weak = null
	if failure_count > 0:
		quit(1)
		return
	print("application_quit_coordinator_smoke: ok")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
