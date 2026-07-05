extends RefCounted


static func prewarm_scene_shell(scene_spawn_flow_handler: Object, scene_shell_handler: Object) -> Dictionary:
	if scene_spawn_flow_handler == null or not scene_spawn_flow_handler.has_method("prewarm_scene_shell"):
		return _empty_result("ready")
	var result_value: Variant = scene_spawn_flow_handler.prewarm_scene_shell(scene_shell_handler)
	var result: Dictionary = result_value if result_value is Dictionary else {}
	return _normalize_result(result, "ready")


static func prewarm_assets_step(
	owner: Object,
	fallback_owner: Object,
	fallback_stage: int,
	use_threaded_texture_loads: bool,
	scene_spawn_flow_handler: Object,
	scene_shell_handler: Object,
	runtime_context_handler: Object
) -> Dictionary:
	if scene_spawn_flow_handler == null or not scene_spawn_flow_handler.has_method("prewarm_assets_step"):
		return _empty_result("done")
	var prewarm_owner: Object = owner if owner != null else fallback_owner
	var selected_character_type: String = _get_result_victory_character_type(runtime_context_handler, prewarm_owner)
	var stage_id: int = fallback_stage
	if prewarm_owner != null:
		stage_id = _get_current_stage(runtime_context_handler, prewarm_owner)
	var result_value: Variant = scene_spawn_flow_handler.prewarm_assets_step(
		scene_shell_handler,
		selected_character_type,
		stage_id,
		use_threaded_texture_loads
	)
	var result: Dictionary = result_value if result_value is Dictionary else {}
	return _normalize_result(result, "done")


static func _get_result_victory_character_type(runtime_context_handler: Object, owner: Object) -> String:
	if runtime_context_handler == null or not runtime_context_handler.has_method("get_result_victory_character_type"):
		return "smasher"
	return str(runtime_context_handler.get_result_victory_character_type(owner))


static func _get_current_stage(runtime_context_handler: Object, owner: Object) -> int:
	if runtime_context_handler == null or not runtime_context_handler.has_method("get_current_stage"):
		return 1
	return int(runtime_context_handler.get_current_stage(owner))


static func _normalize_result(result: Dictionary, completion_key: String) -> Dictionary:
	return {
		completion_key: bool(result.get(completion_key, false)),
		"status": copy_status(result),
	}


static func _empty_result(completion_key: String) -> Dictionary:
	return {
		completion_key: false,
		"status": {},
	}


static func copy_status(result: Dictionary) -> Dictionary:
	var status_value: Variant = result.get("status", {})
	return status_value.duplicate(true) if status_value is Dictionary else {}
