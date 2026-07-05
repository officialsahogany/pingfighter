extends RefCounted

const StageClearResultSceneSpawnShellData := preload("res://scripts/core/stage_clear_result_scene_spawn_shell_data.gd")


static func update_pending_scene_spawn(
	spawn_pending: bool,
	owner: Object,
	registry: Object,
	prewarm_assets_step: Callable,
	spawn_result_scene: Callable,
	reset: Callable
) -> bool:
	if not spawn_pending:
		return false
	if not bool(prewarm_assets_step.call(owner, registry)):
		_queue_redraw(owner)
		return true
	if not bool(spawn_result_scene.call(owner)):
		_call(reset)
		return false
	_queue_redraw(owner)
	return false


static func start_show_scene_spawn(
	owner: Object,
	scene_shell_handler: Object,
	selected_character_type: String,
	stage_id: int,
	spawn_result_scene: Callable,
	reset: Callable
) -> Dictionary:
	if StageClearResultSceneSpawnShellData.are_assets_ready_for_spawn(
		scene_shell_handler,
		selected_character_type,
		stage_id
	):
		if not _call_bool(spawn_result_scene, owner):
			_call(reset)
			return {
				"shown": false,
				"spawn_pending": false,
			}
		return {
			"shown": true,
			"spawn_pending": false,
		}
	_queue_redraw(owner)
	return {
		"shown": true,
		"spawn_pending": true,
	}


static func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


static func _call(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


static func _call_bool(callback: Callable, argument: Variant) -> bool:
	if not callback.is_valid():
		return false
	return bool(callback.call(argument))
