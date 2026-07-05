extends RefCounted

const StageClearResultPrewarmStepData := preload("res://scripts/core/stage_clear_result_prewarm_step_data.gd")
const StageClearResultPrewarmScreenData := preload("res://scripts/core/stage_clear_result_prewarm_screen_data.gd")

var _prewarm_assets_status: Dictionary = {}


func prewarm_assets(owner: Object, registry: Object, prewarm_assets_step_callback: Callable) -> Dictionary:
	while prewarm_assets_step_callback.is_valid() and not bool(prewarm_assets_step_callback.call(owner, registry)):
		pass
	return get_prewarm_status()


func prewarm_assets_from_screen(owner: Object, registry: Object, screen: Object) -> Dictionary:
	return StageClearResultPrewarmScreenData.prewarm_assets_from_screen(
		self,
		owner,
		registry,
		screen
	)


func prewarm_scene_shell(scene_spawn_flow_handler: Object, scene_shell_handler: Object) -> bool:
	var result: Dictionary = StageClearResultPrewarmStepData.prewarm_scene_shell(
		scene_spawn_flow_handler,
		scene_shell_handler
	)
	_apply_prewarm_flow_status(result)
	return bool(result.get("ready", false))


func prewarm_scene_shell_from_screen(screen: Object) -> bool:
	return StageClearResultPrewarmScreenData.prewarm_scene_shell_from_screen(self, screen)


func prewarm_assets_step(
	owner: Object,
	fallback_owner: Object,
	fallback_stage: int,
	use_threaded_texture_loads: bool,
	scene_spawn_flow_handler: Object,
	scene_shell_handler: Object,
	runtime_context_handler: Object
) -> bool:
	var result: Dictionary = StageClearResultPrewarmStepData.prewarm_assets_step(
		owner,
		fallback_owner,
		fallback_stage,
		use_threaded_texture_loads,
		scene_spawn_flow_handler,
		scene_shell_handler,
		runtime_context_handler
	)
	_apply_prewarm_flow_status(result)
	return bool(result.get("done", false))


func prewarm_assets_step_from_screen(
	owner: Object,
	_registry: Object,
	screen: Object,
	use_threaded_texture_loads: bool = false
) -> bool:
	var context: Dictionary = StageClearResultPrewarmScreenData.build_prewarm_assets_step_context_from_screen(screen)
	if context.is_empty():
		clear_prewarm_status()
		return false
	return prewarm_assets_step(
		owner,
		context.get("fallback_owner", null) as Object,
		int(context.get("fallback_stage", 1)),
		use_threaded_texture_loads,
		context.get("scene_spawn_flow_handler", null) as Object,
		context.get("scene_shell_handler", null) as Object,
		context.get("runtime_context_handler", null) as Object
	)


func build_prewarm_assets_step_callback_from_screen(
	screen: Object,
	use_threaded_texture_loads: bool = false
) -> Callable:
	return StageClearResultPrewarmScreenData.build_prewarm_assets_step_callback_from_screen(
		self,
		screen,
		use_threaded_texture_loads
	)


func get_prewarm_status() -> Dictionary:
	return _prewarm_assets_status.duplicate(true)


func clear_prewarm_status() -> void:
	_prewarm_assets_status = {}


func _apply_prewarm_flow_status(result: Dictionary) -> void:
	_prewarm_assets_status = StageClearResultPrewarmStepData.copy_status(result)
